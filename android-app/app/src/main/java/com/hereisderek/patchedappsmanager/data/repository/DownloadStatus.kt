package com.hereisderek.patchedappsmanager.data.repository

sealed class DownloadStatus {
    data class Downloading(val progress: Int) : DownloadStatus()
    object Verifying : DownloadStatus()
    object Installing : DownloadStatus()
    object Success : DownloadStatus()
    data class Error(val message: String) : DownloadStatus()
}
