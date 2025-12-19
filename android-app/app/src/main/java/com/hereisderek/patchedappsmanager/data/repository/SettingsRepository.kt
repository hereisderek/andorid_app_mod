package com.hereisderek.patchedappsmanager.data.repository

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "settings")

@Singleton
class SettingsRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val REPO_URL_KEY = stringPreferencesKey("repo_url")
    private val DEFAULT_REPO_URL = "https://github.com/hereisderek/andorid_app_mod/"

    val repoUrl: Flow<String> = context.dataStore.data
        .map { preferences ->
            preferences[REPO_URL_KEY] ?: DEFAULT_REPO_URL
        }

    suspend fun updateRepoUrl(url: String) {
        context.dataStore.edit { preferences ->
            preferences[REPO_URL_KEY] = url
        }
    }

    suspend fun resetRepoUrl() {
        context.dataStore.edit { preferences ->
            preferences.remove(REPO_URL_KEY)
        }
    }
}
