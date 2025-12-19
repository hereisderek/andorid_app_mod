package com.hereisderek.patchedappsmanager.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.hereisderek.patchedappsmanager.R
import com.hereisderek.patchedappsmanager.data.model.AppInfo
import com.hereisderek.patchedappsmanager.data.model.AppStatus
import com.hereisderek.patchedappsmanager.data.repository.DownloadStatus
import com.hereisderek.patchedappsmanager.ui.viewmodel.AppsUiState
import com.hereisderek.patchedappsmanager.ui.viewmodel.AppsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppsListScreen(
    viewModel: AppsViewModel,
    onNavigateToSettings: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    val filteredApps by viewModel.filteredApps.collectAsState()
    val searchQuery by viewModel.searchQuery.collectAsState()
    val downloadStatuses by viewModel.downloadStatuses.collectAsState()
    val isRefreshing by viewModel.isRefreshing.collectAsState()
    
    var isSearchActive by remember { mutableStateOf(false) }
    
    Scaffold(
        topBar = {
            if (isSearchActive) {
                SearchBar(
                    query = searchQuery,
                    onQueryChange = { viewModel.onSearchQueryChange(it) },
                    onCloseClick = { 
                        isSearchActive = false
                        viewModel.onSearchQueryChange("")
                    }
                )
            } else {
                TopAppBar(
                    title = { Text(stringResource(R.string.app_list_title)) },
                    actions = {
                        IconButton(onClick = { isSearchActive = true }) {
                            Icon(Icons.Default.Search, contentDescription = "Search")
                        }
                        IconButton(onClick = { viewModel.refresh() }) {
                            Icon(Icons.Default.Refresh, contentDescription = stringResource(R.string.refresh))
                        }
                        IconButton(onClick = onNavigateToSettings) {
                            Icon(Icons.Default.Settings, contentDescription = stringResource(R.string.settings_title))
                        }
                    }
                )
            }
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when (val state = uiState) {
                is AppsUiState.Loading -> {
                    CircularProgressIndicator(
                        modifier = Modifier.align(Alignment.Center)
                    )
                }
                is AppsUiState.Success -> {
                    if (filteredApps.isEmpty()) {
                        Text(
                            text = if (searchQuery.isEmpty()) "No apps available" else "No apps match your search",
                            modifier = Modifier.align(Alignment.Center)
                        )
                    } else {
                        LazyColumn(
                            contentPadding = PaddingValues(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                            modifier = Modifier.fillMaxSize()
                        ) {
                            items(filteredApps) { app ->
                                AppListItem(
                                    app = app,
                                    downloadStatus = downloadStatuses[app.packageId],
                                    onInstallClick = { viewModel.downloadAndInstall(app) }
                                )
                            }
                        }
                    }
                }
                is AppsUiState.Error -> {
                    Column(
                        modifier = Modifier.align(Alignment.Center),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(text = stringResource(R.string.error_loading))
                        Text(text = state.message)
                        Button(onClick = { viewModel.loadApps() }) {
                            Text(stringResource(R.string.retry))
                        }
                    }
                }
            }
            
            // Show refreshing indicator
            if (isRefreshing) {
                LinearProgressIndicator(
                    modifier = Modifier
                        .fillMaxWidth()
                        .align(Alignment.TopCenter)
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchBar(
    query: String,
    onQueryChange: (String) -> Unit,
    onCloseClick: () -> Unit
) {
    TopAppBar(
        title = {
            TextField(
                value = query,
                onValueChange = onQueryChange,
                placeholder = { Text("Search apps...") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Color.Transparent,
                    unfocusedContainerColor = Color.Transparent,
                    disabledContainerColor = Color.Transparent,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                )
            )
        },
        navigationIcon = {
            IconButton(onClick = onCloseClick) {
                Icon(Icons.Default.Close, contentDescription = "Close search")
            }
        }
    )
}

@Composable
fun AppListItem(
    app: AppInfo,
    downloadStatus: DownloadStatus?,
    onInstallClick: (AppInfo) -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier
                .padding(16.dp)
                .fillMaxWidth()
        ) {
            Text(
                text = app.name,
                style = MaterialTheme.typography.titleMedium
            )
            Text(
                text = app.packageId,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            
            Spacer(modifier = Modifier.height(8.dp))
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    app.installedVersion?.let {
                        Text(
                            text = "Installed: $it",
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                    Text(
                        text = "Available: ${app.availableVersion}",
                        style = MaterialTheme.typography.bodySmall
                    )
                    Text(
                        text = "Size: ${formatFileSize(app.fileSize)}",
                        style = MaterialTheme.typography.bodySmall
                    )
                }
                
                Box(contentAlignment = Alignment.Center) {
                    if (downloadStatus is DownloadStatus.Downloading) {
                        CircularProgressIndicator(
                            progress = downloadStatus.progress / 100f,
                            modifier = Modifier.size(40.dp)
                        )
                    } else if (downloadStatus is DownloadStatus.Verifying || downloadStatus is DownloadStatus.Installing) {
                        CircularProgressIndicator(modifier = Modifier.size(40.dp))
                    } else {
                        Button(
                            onClick = { onInstallClick(app) },
                            enabled = app.status != AppStatus.UP_TO_DATE
                        ) {
                            Text(
                                text = when (app.status) {
                                    AppStatus.NOT_INSTALLED -> stringResource(R.string.install)
                                    AppStatus.UPDATE_AVAILABLE -> stringResource(R.string.update)
                                    AppStatus.UP_TO_DATE -> stringResource(R.string.up_to_date)
                                }
                            )
                        }
                    }
                }
            }
            
            if (downloadStatus is DownloadStatus.Error) {
                Text(
                    text = downloadStatus.message,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.labelSmall,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }
            
            if (app.status != AppStatus.NOT_INSTALLED) {
                Spacer(modifier = Modifier.height(4.dp))
                StatusChip(status = app.status)
            }
        }
    }
}

@Composable
fun StatusChip(status: AppStatus) {
    Surface(
        color = when (status) {
            AppStatus.UPDATE_AVAILABLE -> MaterialTheme.colorScheme.primaryContainer
            AppStatus.UP_TO_DATE -> MaterialTheme.colorScheme.tertiaryContainer
            else -> MaterialTheme.colorScheme.surface
        },
        shape = MaterialTheme.shapes.small
    ) {
        Text(
            text = when (status) {
                AppStatus.UPDATE_AVAILABLE -> "Update Available"
                AppStatus.UP_TO_DATE -> "Up to Date"
                AppStatus.NOT_INSTALLED -> "Not Installed"
            },
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            style = MaterialTheme.typography.labelSmall
        )
    }
}

fun formatFileSize(bytes: Long): String {
    val kb = bytes / 1024.0
    val mb = kb / 1024.0
    return when {
        mb >= 1 -> "%.2f MB".format(mb)
        kb >= 1 -> "%.2f KB".format(kb)
        else -> "$bytes B"
    }
}
