package com.hereisderek.patchedappsmanager.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class GitHubRelease(
    @Json(name = "id")
    val id: Long,
    @Json(name = "tag_name")
    val tagName: String,
    @Json(name = "name")
    val name: String?,
    @Json(name = "assets")
    val assets: List<ReleaseAsset>,
    @Json(name = "published_at")
    val publishedAt: String
)

@JsonClass(generateAdapter = true)
data class ReleaseAsset(
    @Json(name = "name")
    val name: String,
    @Json(name = "browser_download_url")
    val browserDownloadUrl: String,
    @Json(name = "size")
    val size: Long
)
