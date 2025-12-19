package com.hereisderek.patchedappsmanager.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hereisderek.patchedappsmanager.data.model.AppInfo
import com.hereisderek.patchedappsmanager.data.repository.AppsRepository
import com.hereisderek.patchedappsmanager.data.repository.DownloadStatus
import com.hereisderek.patchedappsmanager.data.repository.SettingsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest

sealed class AppsUiState {
    object Loading : AppsUiState()
    data class Success(val apps: List<AppInfo>) : AppsUiState()
    data class Error(val message: String) : AppsUiState()
}

@HiltViewModel
class AppsViewModel @Inject constructor(
    private val repository: AppsRepository,
    private val settingsRepository: SettingsRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow<AppsUiState>(AppsUiState.Loading)
    val uiState: StateFlow<AppsUiState> = _uiState.asStateFlow()
    
    val repositoryUrl: StateFlow<String> = settingsRepository.repoUrl
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), "https://github.com/hereisderek/andorid_app_mod/")

    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

    private val _downloadStatuses = MutableStateFlow<Map<String, DownloadStatus>>(emptyMap())
    val downloadStatuses: StateFlow<Map<String, DownloadStatus>> = _downloadStatuses.asStateFlow()

    private val _isRefreshing = MutableStateFlow(false)
    val isRefreshing: StateFlow<Boolean> = _isRefreshing.asStateFlow()
    
    val filteredApps: StateFlow<List<AppInfo>> = combine(_uiState, _searchQuery) { state, query ->
        if (state is AppsUiState.Success) {
            if (query.isEmpty()) {
                state.apps
            } else {
                state.apps.filter { 
                    it.name.contains(query, ignoreCase = true) || 
                    it.packageId.contains(query, ignoreCase = true) 
                }
            }
        } else {
            emptyList()
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    init {
        viewModelScope.launch {
            repositoryUrl.collect {
                loadApps()
            }
        }
    }
    
    fun onSearchQueryChange(query: String) {
        _searchQuery.value = query
    }

    fun loadApps() {
        viewModelScope.launch {
            _uiState.value = AppsUiState.Loading
            repository.getAvailableApps(repositoryUrl.value)
                .onSuccess { apps ->
                    _uiState.value = AppsUiState.Success(apps)
                }
                .onFailure { error ->
                    _uiState.value = AppsUiState.Error(error.message ?: "Unknown error")
                }
        }
    }

    fun refresh() {
        viewModelScope.launch {
            _isRefreshing.value = true
            repository.getAvailableApps(repositoryUrl.value)
                .onSuccess { apps ->
                    _uiState.value = AppsUiState.Success(apps)
                }
                .onFailure { error ->
                    _uiState.value = AppsUiState.Error(error.message ?: "Unknown error")
                }
            _isRefreshing.value = false
        }
    }

    fun downloadAndInstall(app: AppInfo) {
        viewModelScope.launch {
            repository.downloadAndInstall(app).collect { status ->
                _downloadStatuses.value = _downloadStatuses.value + (app.packageId to status)
                if (status is DownloadStatus.Success || status is DownloadStatus.Error) {
                    // Refresh app list to update installed versions/status
                    refresh()
                }
            }
        }
    }
    
    fun updateRepositoryUrl(url: String) {
        viewModelScope.launch {
            settingsRepository.updateRepoUrl(url)
        }
    }
    
    fun resetRepositoryUrl() {
        viewModelScope.launch {
            settingsRepository.resetRepoUrl()
        }
    }
}
