package com.hereisderek.patchedappsmanager.data.model

data class AppInfo(
    val packageId: String,
    val name: String,
    val iconUrl: String? = null,
    val availableVersion: String,
    val installedVersion: String? = null,
    val downloadUrl: String,
    val fileSize: Long,
    val status: AppStatus,
    val signatureMatch: Boolean? = null
)

enum class AppStatus {
    NOT_INSTALLED,
    UPDATE_AVAILABLE,
    UP_TO_DATE
}
