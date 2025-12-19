package com.hereisderek.patchedappsmanager.data.remote

import com.hereisderek.patchedappsmanager.data.model.AppsConfig
import com.hereisderek.patchedappsmanager.data.model.GitHubRelease
import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.GET
import retrofit2.http.Path
import retrofit2.http.Streaming
import retrofit2.http.Url

interface GitHubApi {
    
    @GET
    suspend fun getAppsConfig(@Url url: String): AppsConfig
    
    @GET("repos/{owner}/{repo}/releases")
    suspend fun getReleases(
        @Path("owner") owner: String,
        @Path("repo") repo: String
    ): List<GitHubRelease>

    @Streaming
    @GET
    suspend fun downloadFile(@Url url: String): Response<ResponseBody>
}
