package com.sylionixtech.payqr

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context

class MainActivity: FlutterActivity() {
    
    private val CHANNEL = "secure_admob_config"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up platform channel for secure AdMob keys
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAdMobAppId" -> {
                    try {
                        val appId = SecureKeys.getInstance().getAdMobAppId(this)
                        result.success(appId)
                    } catch (e: Exception) {
                        result.error("SECURITY_ERROR", "Failed to get AdMob App ID", e.message)
                    }
                }
                "getBannerAdUnitId" -> {
                    try {
                        val adUnitId = SecureKeys.getInstance().getBannerAdUnitId(this)
                        result.success(adUnitId)
                    } catch (e: Exception) {
                        result.error("SECURITY_ERROR", "Failed to get Banner Ad Unit ID", e.message)
                    }
                }
                "getInterstitialAdUnitId" -> {
                    try {
                        val adUnitId = SecureKeys.getInstance().getInterstitialAdUnitId(this)
                        result.success(adUnitId)
                    } catch (e: Exception) {
                        result.error("SECURITY_ERROR", "Failed to get Interstitial Ad Unit ID", e.message)
                    }
                }
                "getRewardedAdUnitId" -> {
                    try {
                        val adUnitId = SecureKeys.getInstance().getRewardedAdUnitId(this)
                        result.success(adUnitId)
                    } catch (e: Exception) {
                        result.error("SECURITY_ERROR", "Failed to get Rewarded Ad Unit ID", e.message)
                    }
                }
                "getAllKeys" -> {
                    try {
                        val keys = SecureKeys.getInstance().getAllKeys(this)
                        result.success(keys)
                    } catch (e: Exception) {
                        result.error("SECURITY_ERROR", "Failed to get all AdMob keys", e.message)
                    }
                    }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
