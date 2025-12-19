package com.hereisderek.patchedappsmanager.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.hereisderek.patchedappsmanager.R
import com.hereisderek.patchedappsmanager.ui.viewmodel.AppsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    viewModel: AppsViewModel,
    onNavigateBack: () -> Unit
) {
    val repositoryUrl by viewModel.repositoryUrl.collectAsState()
    var editedUrl by remember { mutableStateOf(repositoryUrl) }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.settings_title)) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = "Repository Configuration",
                style = MaterialTheme.typography.titleMedium
            )
            
            OutlinedTextField(
                value = editedUrl,
                onValueChange = { editedUrl = it },
                label = { Text(stringResource(R.string.repository_url)) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Button(
                    onClick = {
                        viewModel.updateRepositoryUrl(editedUrl)
                    },
                    modifier = Modifier.weight(1f)
                ) {
                    Text("Save")
                }
                
                OutlinedButton(
                    onClick = {
                        viewModel.resetRepositoryUrl()
                        editedUrl = "https://github.com/hereisderek/andorid_app_mod/"
                    },
                    modifier = Modifier.weight(1f)
                ) {
                    Text(stringResource(R.string.reset_to_default))
                }
            }
            
            Divider()
            
            Text(
                text = "About",
                style = MaterialTheme.typography.titleMedium
            )
            
            Text(
                text = "Patched Apps Manager",
                style = MaterialTheme.typography.bodyLarge
            )
            Text(
                text = "Version 1.0.0",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
