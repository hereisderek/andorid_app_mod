package com.hereisderek.patchedappsmanager.data.repository

import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.content.FileProvider
import com.hereisderek.patchedappsmanager.data.model.AppInfo
import com.hereisderek.patchedappsmanager.data.model.AppStatus
import com.hereisderek.patchedappsmanager.data.remote.GitHubApi
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AppsRepository @Inject constructor(
    @ApplicationContext private val context: Context,
    private val gitHubApi: GitHubApi
) {
    
    suspend fun getAvailableApps(repoUrl: String): Result<List<AppInfo>> = withContext(Dispatchers.IO) {
        try {
            val (owner, repo) = parseGitHubUrl(repoUrl)
            val appsConfigUrl = "https://raw.githubusercontent.com/$owner/$repo/master/apps.json"
            
            val appsConfig = gitHubApi.getAppsConfig(appsConfigUrl)
            val releases = gitHubApi.getReleases(owner, repo)
            
            val appInfoList = appsConfig.apps.mapNotNull { appEntry ->
                val packageId = appEntry.id
                val latestRelease = findLatestReleaseForApp(packageId, releases) ?: return@mapNotNull null
                
                val apkAsset = latestRelease.assets.firstOrNull { 
                    it.name.endsWith(".apk")
                } ?: return@mapNotNull null
                
                val availableVersion = extractVersionFromTag(latestRelease.tagName, packageId)
                val installedVersion = getInstalledVersion(packageId)
                val status = determineAppStatus(installedVersion, availableVersion)
                
                AppInfo(
                    packageId = packageId,
                    name = latestRelease.name ?: packageId,
                    availableVersion = availableVersion,
                    installedVersion = installedVersion,
                    downloadUrl = apkAsset.browserDownloadUrl,
                    fileSize = apkAsset.size,
                    status = status
                )
            }
            
            Result.success(appInfoList)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    fun downloadAndInstall(app: AppInfo): Flow<DownloadStatus> = flow {
        emit(DownloadStatus.Downloading(0))
        
        try {
            val response = gitHubApi.downloadFile(app.downloadUrl)
            if (!response.isSuccessful) {
                emit(DownloadStatus.Error("Failed to download: ${response.message()}"))
                return@flow
            }
            
            val body = response.body()
            if (body == null) {
                emit(DownloadStatus.Error("Empty response body"))
                return@flow
            }
            
            val cacheDir = File(context.cacheDir, "apks")
            if (!cacheDir.exists()) {
                cacheDir.mkdirs()
            }
            
            val apkFile = File(cacheDir, "${app.packageId}-${app.availableVersion}.apk")
            val totalBytes = body.contentLength()
            var bytesRead = 0L
            
            body.byteStream().use { input ->
                FileOutputStream(apkFile).use { output ->
                    val buffer = ByteArray(8192)
                    var read: Int
                    while (input.read(buffer).also { read = it } != -1) {
                        output.write(buffer, 0, read)
                        bytesRead += read
                        if (totalBytes > 0) {
                            emit(DownloadStatus.Downloading((bytesRead * 100 / totalBytes).toInt()))
                        }
                    }
                }
            }
            
            emit(DownloadStatus.Verifying)
            val signatureMatch = verifySignature(app.packageId, apkFile)
            if (signatureMatch == false) {
                emit(DownloadStatus.Error("Signature mismatch! You must uninstall the existing app first."))
                return@flow
            }

            emit(DownloadStatus.Installing)
            installApk(apkFile)
            emit(DownloadStatus.Success)
        } catch (e: Exception) {
            emit(DownloadStatus.Error(e.message ?: "Download failed"))
        }
    }
    
    private fun verifySignature(packageId: String, apkFile: File): Boolean? {
        val installedSignature = getInstalledSignature(packageId) ?: return null
        val apkSignature = getApkSignature(apkFile) ?: return null
        
        return installedSignature == apkSignature
    }

    private fun getInstalledSignature(packageId: String): String? {
        return try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                context.packageManager.getPackageInfo(packageId, PackageManager.GET_SIGNING_CERTIFICATES)
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(packageId, PackageManager.GET_SIGNATURES)
            }
            
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                packageInfo.signatures
            }
            
            signatures?.firstOrNull()?.toSha256()
        } catch (e: Exception) {
            null
        }
    }

    private fun getApkSignature(file: File): String? {
        return try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                context.packageManager.getPackageArchiveInfo(file.absolutePath, PackageManager.GET_SIGNING_CERTIFICATES)
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageArchiveInfo(file.absolutePath, PackageManager.GET_SIGNATURES)
            }
            
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo?.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                packageInfo?.signatures
            }
            
            signatures?.firstOrNull()?.toSha256()
        } catch (e: Exception) {
            null
        }
    }

    private fun Signature.toSha256(): String {
        val md = MessageDigest.getInstance("SHA-256")
        val digest = md.digest(toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }

    private fun installApk(file: File) {
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file
        )
        
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
        }
        
        context.startActivity(intent)
    }
    
    private fun parseGitHubUrl(url: String): Pair<String, String> {
        val regex = """github\.com[:/]([^/]+)/([^/]+)""".toRegex()
        val match = regex.find(url) ?: throw IllegalArgumentException("Invalid GitHub URL")
        return match.groupValues[1] to match.groupValues[2].removeSuffix(".git")
    }
    
    private fun findLatestReleaseForApp(packageId: String, releases: List<com.hereisderek.patchedappsmanager.data.model.GitHubRelease>): com.hereisderek.patchedappsmanager.data.model.GitHubRelease? {
        return releases.firstOrNull { release ->
            release.tagName.startsWith("$packageId-v")
        }
    }
    
    private fun extractVersionFromTag(tagName: String, packageId: String): String {
        return tagName.removePrefix("$packageId-v")
    }
    
    private fun getInstalledVersion(packageId: String): String? {
        return try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.packageManager.getPackageInfo(packageId, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(packageId, 0)
            }
            packageInfo.versionName
        } catch (e: PackageManager.NameNotFoundException) {
            null
        }
    }
    
    private fun determineAppStatus(installedVersion: String?, availableVersion: String): AppStatus {
        return when {
            installedVersion == null -> AppStatus.NOT_INSTALLED
            compareVersions(installedVersion, availableVersion) < 0 -> AppStatus.UPDATE_AVAILABLE
            else -> AppStatus.UP_TO_DATE
        }
    }
    
    private fun compareVersions(v1: String, v2: String): Int {
        val parts1 = v1.split(".").map { it.toIntOrNull() ?: 0 }
        val parts2 = v2.split(".").map { it.toIntOrNull() ?: 0 }
        val maxLength = maxOf(parts1.size, parts2.size)
        
        for (i in 0 until maxLength) {
            val p1 = parts1.getOrNull(i) ?: 0
            val p2 = parts2.getOrNull(i) ?: 0
            if (p1 != p2) return p1.compareTo(p2)
        }
        return 0
    }
}
