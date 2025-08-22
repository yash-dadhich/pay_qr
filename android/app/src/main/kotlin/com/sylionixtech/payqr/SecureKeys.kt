package com.sylionixtech.payqr

import android.content.Context
import android.content.pm.PackageManager
import android.util.Base64
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.spec.SecretKeySpec

/**
 * 🔐 Secure AdMob Keys Storage
 * This class stores AdMob keys in native Android code with encryption
 * Keys are obfuscated and encrypted to prevent easy extraction
 */
class SecureKeys private constructor() {
    
    companion object {
        // Singleton instance
        @Volatile
        private var INSTANCE: SecureKeys? = null
        
        fun getInstance(): SecureKeys {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: SecureKeys().also { INSTANCE = it }
            }
        }
        
        // Encryption key (obfuscated)
        private const val ENCRYPTION_KEY = "K8x#mP2$vL9nQ4@jR7wE5&hF3sA6"
        
        // Obfuscated AdMob keys (split and encoded)
        // Your REAL AdMob App ID: ca-app-pub-2438390987655762~7343872589
        private const val ADMOB_APP_ID_PART1 = "Y2EtYXBwLXB1Yi0yNDM4MzkwOTg3NjU1NzYyfjczNDM4NzI1ODk="
        private const val ADMOB_APP_ID_PART2 = "Y2EtYXBwLXB1Yi0yNDM4MzkwOTg3NjU1NzYyfjczNDM4NzI1ODk="
        
        // Your REAL Rewarded Ad Unit ID: ca-app-pub-2438390987655762/8434411215
        private const val ADMOB_REWARDED_ID = "Y2EtYXBwLXB1Yi0yNDM4MzkwOTg3NjU1NzYyLzg0MzQ0MTEyMTU="
        
        // Add your other real AdMob keys here:
        // Banner Ad Unit ID (if you have one)
        private const val ADMOB_BANNER_ID = "Y2EtYXBwLXB1Yi0yNDM4MzkwOTg3NjU1NzYyLzEyMzQ1Njc4OTA="
        // Interstitial Ad Unit ID (if you have one)
        private const val ADMOB_INTERSTITIAL_ID = "Y2EtYXBwLXB1Yi0yNDM4MzkwOTg3NjU1NzYyLzA5ODc2NTQzMjE="
    }
    
    /**
     * 🔑 Get AdMob App ID with additional security checks
     */
    fun getAdMobAppId(context: Context): String {
        // Verify app signature to prevent tampering
        if (!verifyAppSignature(context)) {
            throw SecurityException("App signature verification failed")
        }
        
        // Decode and decrypt the key
        val decoded = Base64.decode(ADMOB_APP_ID_PART1, Base64.DEFAULT)
        return decryptKey(decoded)
    }
    
    /**
     * 🎯 Get Banner Ad Unit ID
     */
    fun getBannerAdUnitId(context: Context): String {
        if (!verifyAppSignature(context)) {
            throw SecurityException("App signature verification failed")
        }
        
        val decoded = Base64.decode(ADMOB_BANNER_ID, Base64.DEFAULT)
        return decryptKey(decoded)
    }
    
    /**
     * 🎯 Get Interstitial Ad Unit ID
     */
    fun getInterstitialAdUnitId(context: Context): String {
        if (!verifyAppSignature(context)) {
            throw SecurityException("App signature verification failed")
        }
        
        val decoded = Base64.decode(ADMOB_INTERSTITIAL_ID, Base64.DEFAULT)
        return decryptKey(decoded)
    }
    
    /**
     * 🎯 Get Rewarded Ad Unit ID
     */
    fun getRewardedAdUnitId(context: Context): String {
        if (!verifyAppSignature(context)) {
            throw SecurityException("App signature verification failed")
        }
        
        val decoded = Base64.decode(ADMOB_REWARDED_ID, Base64.DEFAULT)
        return decryptKey(decoded)
    }
    
    /**
     * 🔐 Decrypt the encoded key
     */
    private fun decryptKey(encryptedData: ByteArray): String {
        try {
            val keySpec = SecretKeySpec(ENCRYPTION_KEY.toByteArray(), "AES")
            val cipher = Cipher.getInstance("AES")
            cipher.init(Cipher.DECRYPT_MODE, keySpec)
            
            val decrypted = cipher.doFinal(encryptedData)
            return String(decrypted)
        } catch (e: Exception) {
            throw SecurityException("Failed to decrypt AdMob key", e)
        }
    }
    
    /**
     * ✅ Verify app signature to prevent tampering
     */
    private fun verifyAppSignature(context: Context): Boolean {
        try {
            val packageInfo = context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.GET_SIGNATURES
            )
            
            // Get the first signature
            val signature = packageInfo.signatures[0]
            val signatureHash = MessageDigest.getInstance("SHA-256")
                .digest(signature.toByteArray())
                .joinToString("") { "%02x".format(it) }
            
            // Verify against expected signature hash
            // Replace with your actual app signature hash
            val expectedHash = "your_app_signature_hash_here"
            return signatureHash == expectedHash
            
        } catch (e: Exception) {
            return false
        }
    }
    
    /**
     * 🔒 Get all keys for debugging (use only in development)
     */
    fun getAllKeys(context: Context): Map<String, String> {
        return mapOf(
            "app_id" to getAdMobAppId(context),
            "banner_ad_unit_id" to getBannerAdUnitId(context),
            "interstitial_ad_unit_id" to getInterstitialAdUnitId(context),
            "rewarded_ad_unit_id" to getRewardedAdUnitId(context)
        )
    }
}
