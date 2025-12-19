package com.hereisderek.patchedappsmanager.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class AppsConfig(
    @Json(name = "apps")
    val apps: List<AppEntry>
)

@JsonClass(generateAdapter = true)
data class AppEntry(
    @Json(name = "id")
    val id: String
)
