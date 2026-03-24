package com.hereisderek.aia.xposed

import android.content.Context
import de.robv.android.xposed.*
import de.robv.android.xposed.callbacks.XC_LoadPackage
import de.robv.android.xposed.XSharedPreferences

class MainHook : IXposedHookLoadPackage {

    private val prefs = XSharedPreferences("com.hereisderek.aia.xposed", "xposed_settings")

    private val patches = mapOf(
        45 to PatchV45()
    )

    override fun handleLoadPackage(lpparam: XC_LoadPackage.LoadPackageParam) {
        if (lpparam.packageName != "com.aia.gr.rn.nz.v2022.vitality") return

        prefs.reload()
        XposedBridge.log("AIA Vitality Bypass: Loading hooks for ${lpparam.packageName}")

        val specificPatch = patches[45] // Default to V45 logic for now
        specificPatch?.apply(lpparam, prefs)
    }

    interface VersionPatch {
        fun apply(lpparam: XC_LoadPackage.LoadPackageParam, prefs: XSharedPreferences): Boolean
    }

    class PatchV45 : VersionPatch {
        override fun apply(lpparam: XC_LoadPackage.LoadPackageParam, prefs: XSharedPreferences): Boolean {
            try {
                val enableBypass = prefs.getBoolean("enable_bypass", true)
                val detailedLogging = prefs.getBoolean("detailed_logging", true)

                if (enableBypass) {
                    applySecurityBypass(lpparam)
                }

                applyHealthHooks(lpparam, prefs, detailedLogging)

                return true
            } catch (e: Throwable) {
                XposedBridge.log("AIA Vitality Bypass: Patching failed: ${e.message}")
                return false
            }
        }

        private fun applySecurityBypass(lpparam: XC_LoadPackage.LoadPackageParam) {
            val cl = lpparam.classLoader
            XposedHelpers.findAndHookMethod("be.c", cl, "c", XC_MethodReplacement.returnConstant(false))
            XposedHelpers.findAndHookMethod("zd.a", cl, "c", Context::class.java, XC_MethodReplacement.returnConstant(false))
            XposedHelpers.findAndHookMethod("ae.a", cl, "a", Context::class.java, XC_MethodReplacement.returnConstant(false))
            XposedHelpers.findAndHookMethod("yd.a", cl, "a", Context::class.java, XC_MethodReplacement.returnConstant(false))
            XposedHelpers.findAndHookMethod("xd.a", cl, "a", Context::class.java, XC_MethodReplacement.returnConstant(false))
            XposedHelpers.findAndHookMethod("com.scottyab.rootbeer.RootBeerNative", cl, "a", XC_MethodReplacement.returnConstant(false))
            XposedHelpers.findAndHookMethod("com.pairip.licensecheck.LicenseActivity", cl, "onStart", XC_MethodReplacement.DO_NOTHING)
            XposedHelpers.findAndHookMethod("com.pairip.licensecheck.LicenseActivity", cl, "closeApp", XC_MethodReplacement.DO_NOTHING)
            XposedHelpers.findAndHookMethod("com.pairip.licensecheck.LicenseClient", cl, "initializeLicenseCheck", XC_MethodReplacement.DO_NOTHING)
            XposedHelpers.findAndHookMethod("com.pairip.licensecheck.LicenseClient", cl, "performLocalInstallerCheck", XC_MethodReplacement.returnConstant(true))
        }

        private fun applyHealthHooks(lpparam: XC_LoadPackage.LoadPackageParam, prefs: XSharedPreferences, logging: Boolean) {
            val cl = lpparam.classLoader
            
            // 1. Hook the primary data injection point in GoogleFitStepCounter
            XposedHelpers.findAndHookMethod(
                "com.vitalityhealthkit.GoogleFitStepCounter", cl, "putValueIntoReadingObject",
                MutableMap::class.java, "com.google.android.gms.fitness.data.DataPoint", "uf.c", String::class.java,
                object : XC_MethodHook() {
                    override fun afterHookedMethod(param: MethodHookParam) {
                        val map = param.args[0] as MutableMap<String, Any>
                        val field = param.args[2]
                        val fieldName = XposedHelpers.callMethod(field, "j") as String
                        val originalValue = map[fieldName]?.toString()

                        var injected = false
                        var reason = ""

                        when (fieldName) {
                            "steps" -> {
                                if (prefs.getBoolean("enable_step_hook", false)) {
                                    val multiplier = prefs.getString("step_multiplier", "1.0")?.toFloatOrNull() ?: 1.0f
                                    val fixedSteps = prefs.getString("fixed_steps", "")?.toIntOrNull()
                                    val original = originalValue?.toIntOrNull() ?: 0
                                    val newVal = fixedSteps ?: (original * multiplier).toInt()
                                    map[fieldName] = newVal.toString()
                                    injected = true
                                } else {
                                    reason = "Step hook disabled"
                                }
                            }
                            "duration", "active_minutes", "minutes" -> {
                                if (prefs.getBoolean("enable_workout_hook", false)) {
                                    val multiplier = prefs.getString("workout_multiplier", "1.0")?.toFloatOrNull() ?: 1.0f
                                    val original = originalValue?.toFloatOrNull() ?: 0f
                                    val newVal = (original * multiplier).toInt()
                                    map[fieldName] = newVal.toString()
                                    injected = true
                                } else {
                                    reason = "Workout hook disabled"
                                }
                            }
                            "calories" -> {
                                if (prefs.getBoolean("enable_workout_hook", false)) {
                                    val multiplier = prefs.getString("workout_multiplier", "1.0")?.toFloatOrNull() ?: 1.0f
                                    val original = originalValue?.toFloatOrNull() ?: 0f
                                    val newVal = (original * multiplier).toInt()
                                    map[fieldName] = newVal.toString()
                                    injected = true
                                }
                            }
                            "heart_rate", "heartRate", "avgHeartRate" -> {
                                if (prefs.getBoolean("enable_hr_hook", false)) {
                                    val fixedHr = prefs.getString("fixed_hr", "72")
                                    map[fieldName] = fixedHr!!
                                    injected = true
                                } else {
                                    reason = "HR hook disabled"
                                }
                            }
                            "sleep_segment_type", "sleep_minutes" -> {
                                if (prefs.getBoolean("enable_sleep_hook", false)) {
                                    val fixedSleep = prefs.getString("fixed_sleep_minutes", "480")
                                    map[fieldName] = fixedSleep!!
                                    injected = true
                                } else {
                                    reason = "Sleep hook disabled"
                                }
                            }
                        }

                        if (logging) {
                            if (injected) {
                                XposedBridge.log("AIA Vitality [INJECTED]: $fieldName = ${map[fieldName]} (was $originalValue)")
                            } else {
                                val skipMsg = if (reason.isNotEmpty()) " (Reason: $reason)" else ""
                                XposedBridge.log("AIA Vitality [SKIPPED]: $fieldName = $originalValue$skipMsg")
                            }
                        }
                    }
                }
            )

            // 2. Hook Heart Rate specific average calculation
            XposedHelpers.findAndHookMethod(
                "com.vitalityhealthkit.GoogleFitStepCounter", cl, "readAvgHeartRate",
                String::class.java, MutableMap::class.java, "com.google.android.gms.fitness.data.DataPoint", "uf.c", String::class.java,
                object : XC_MethodHook() {
                    override fun afterHookedMethod(param: MethodHookParam) {
                        if (prefs.getBoolean("enable_hr_hook", false)) {
                            val map = param.args[1] as MutableMap<String, Any>
                            val fixedHr = prefs.getString("fixed_hr", "72")!!
                            map["avgHeartRate"] = fixedHr
                            map["bpmSum"] = fixedHr
                            map["numBpmReadings"] = "1"
                            if (logging) XposedBridge.log("AIA Vitality [INJECTED]: avgHeartRate = $fixedHr")
                        }
                    }
                }
            )
        }
    }
}
