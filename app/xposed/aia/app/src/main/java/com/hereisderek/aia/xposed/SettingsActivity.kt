package com.hereisderek.aia.xposed

import android.content.Context
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.preference.PreferenceFragmentCompat

class SettingsActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) {
            supportFragmentManager
                .beginTransaction()
                .replace(android.R.id.content, SettingsFragment())
                .commit()
        }
    }

    class SettingsFragment : PreferenceFragmentCompat() {
        override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
            // With xposedminversion 93, LSPosed allows MODE_WORLD_READABLE
            // by hooking the system calls.
            preferenceManager.sharedPreferencesName = "xposed_settings"
            @Suppress("DEPRECATION")
            preferenceManager.sharedPreferencesMode = Context.MODE_WORLD_READABLE
            setPreferencesFromResource(R.xml.preferences, rootKey)
        }
    }
}
