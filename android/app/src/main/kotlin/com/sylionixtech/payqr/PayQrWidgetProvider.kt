package com.sylionixtech.payqr

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import org.json.JSONArray
import org.json.JSONObject

class PayQrWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val ACTION_PREV = "com.sylionixtech.payqr.ACTION_PREV"
        private const val ACTION_NEXT = "com.sylionixtech.payqr.ACTION_NEXT"
        private const val PREFS_NAME = "HomeWidgetPreferences"
        private const val KEY_UPI_LIST = "upi_list_json"
        private const val KEY_SELECTED_INDEX = "selected_index"
        private const val TAG = "PayQrWidgetProvider"

        private fun dpToPx(context: Context, dp: Int): Int {
            return (dp * context.resources.displayMetrics.density).toInt()
        }

        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val upiListJson = prefs.getString(KEY_UPI_LIST, "[]") ?: "[]"
            var selectedIndex = prefs.getInt(KEY_SELECTED_INDEX, 0)

            Log.d(TAG, "updateAppWidget: listJson=$upiListJson, index=$selectedIndex")

            try {
                val array = JSONArray(upiListJson)
                if (array.length() > 0) {
                    if (selectedIndex < 0 || selectedIndex >= array.length()) {
                        selectedIndex = 0
                    }

                    val currentProfile = array.getJSONObject(selectedIndex)
                    val name = currentProfile.optString("name", "Unknown Payee")
                    val upiId = currentProfile.optString("upiId", "")

                    views.setTextViewText(R.id.widget_payee_name, name)
                    views.setTextViewText(R.id.widget_payee_upi, upiId)

                    // Generate UPI Payment URI
                    // upi://pay?pa=upiId&pn=name
                    if (upiId.isNotEmpty()) {
                        val encodedName = Uri.encode(name)
                        val qrData = "upi://pay?pa=$upiId&pn=$encodedName"
                        val qrBitmap = generateQrCode(context, qrData)
                        if (qrBitmap != null) {
                            val paddingPx = dpToPx(context, 8)
                            views.setViewPadding(R.id.widget_qr_image, paddingPx, paddingPx, paddingPx, paddingPx)
                            views.setImageViewBitmap(R.id.widget_qr_image, qrBitmap)
                        } else {
                            val paddingPx = dpToPx(context, 64)
                            views.setViewPadding(R.id.widget_qr_image, paddingPx, paddingPx, paddingPx, paddingPx)
                            views.setImageViewResource(R.id.widget_qr_image, R.mipmap.ic_launcher)
                        }
                    } else {
                        val paddingPx = dpToPx(context, 64)
                        views.setViewPadding(R.id.widget_qr_image, paddingPx, paddingPx, paddingPx, paddingPx)
                        views.setImageViewResource(R.id.widget_qr_image, R.mipmap.ic_launcher)
                    }
                } else {
                    views.setTextViewText(R.id.widget_payee_name, "No Saved Accounts")
                    views.setTextViewText(R.id.widget_payee_upi, "Open app to add UPI IDs")
                    val paddingPx = dpToPx(context, 64)
                    views.setViewPadding(R.id.widget_qr_image, paddingPx, paddingPx, paddingPx, paddingPx)
                    views.setImageViewResource(R.id.widget_qr_image, R.mipmap.ic_launcher)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error updating widget state", e)
                views.setTextViewText(R.id.widget_payee_name, "Error Loading")
                views.setTextViewText(R.id.widget_payee_upi, "Tap to re-sync")
            }

            // Click pending intent on background root to launch app
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            if (intent != null) {
                val pendingIntent = PendingIntent.getActivity(
                    context, 0, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            // Prev and Next buttons PendingIntents
            val prevIntent = Intent(context, PayQrWidgetProvider::class.java).apply {
                action = ACTION_PREV
            }
            val nextIntent = Intent(context, PayQrWidgetProvider::class.java).apply {
                action = ACTION_NEXT
            }

            val prevPending = PendingIntent.getBroadcast(
                context, 1, prevIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val nextPending = PendingIntent.getBroadcast(
                context, 2, nextIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            views.setOnClickPendingIntent(R.id.btn_prev, prevPending)
            views.setOnClickPendingIntent(R.id.btn_next, nextPending)

            // Instruct the widget manager to update the widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun drawableToBitmap(drawable: Drawable): Bitmap {
            if (drawable is BitmapDrawable) {
                if (drawable.bitmap != null) {
                    return drawable.bitmap
                }
            }
            val bitmap = if (drawable.intrinsicWidth <= 0 || drawable.intrinsicHeight <= 0) {
                Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
            } else {
                Bitmap.createBitmap(drawable.intrinsicWidth, drawable.intrinsicHeight, Bitmap.Config.ARGB_8888)
            }
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            return bitmap
        }

        private fun generateQrCode(context: Context, content: String): Bitmap? {
            return try {
                val writer = QRCodeWriter()
                val size = 512
                val hints = HashMap<EncodeHintType, Any>()
                hints[EncodeHintType.ERROR_CORRECTION] = ErrorCorrectionLevel.Q
                hints[EncodeHintType.MARGIN] = 1
                val bitMatrix = writer.encode(content, BarcodeFormat.QR_CODE, size, size, hints)
                val width = bitMatrix.width
                val height = bitMatrix.height
                val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                for (x in 0 until width) {
                    for (y in 0 until height) {
                        bmp.setPixel(x, y, if (bitMatrix.get(x, y)) Color.BLACK else Color.WHITE)
                    }
                }

                // Draw logo in the center
                try {
                    val drawable = context.resources.getDrawable(R.mipmap.ic_launcher, context.theme)
                    if (drawable != null) {
                        val logoBitmap = drawableToBitmap(drawable)
                        val canvas = Canvas(bmp)
                        
                        // Calculate logo dimensions (e.g., 9% of QR size)
                        val logoSize = (size * 0.09).toInt()
                        val scaledLogo = Bitmap.createScaledBitmap(logoBitmap, logoSize, logoSize, true)
                        
                        // Center coordinates
                        val left = (size - logoSize) / 2
                        val top = (size - logoSize) / 2
                        
                        // Draw a white background under the logo to clear QR pixels in center
                        val paint = Paint().apply {
                            color = Color.WHITE
                            style = Paint.Style.FILL
                        }
                        val border = 4
                        canvas.drawRect(
                            (left - border).toFloat(),
                            (top - border).toFloat(),
                            (left + logoSize + border).toFloat(),
                            (top + logoSize + border).toFloat(),
                            paint
                        )
                        
                        // Draw the logo bitmap
                        canvas.drawBitmap(scaledLogo, left.toFloat(), top.toFloat(), null)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to draw logo on QR", e)
                }

                bmp
            } catch (e: Exception) {
                Log.e(TAG, "QR generation failed", e)
                null
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_PREV || intent.action == ACTION_NEXT) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val upiListJson = prefs.getString(KEY_UPI_LIST, "[]") ?: "[]"
            var selectedIndex = prefs.getInt(KEY_SELECTED_INDEX, 0)

            try {
                val array = JSONArray(upiListJson)
                if (array.length() > 0) {
                    if (intent.action == ACTION_PREV) {
                        selectedIndex = (selectedIndex - 1 + array.length()) % array.length()
                    } else if (intent.action == ACTION_NEXT) {
                        selectedIndex = (selectedIndex + 1) % array.length()
                    }
                    prefs.edit().putInt(KEY_SELECTED_INDEX, selectedIndex).apply()
                    Log.d(TAG, "onReceive: cycled index to $selectedIndex")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error handling navigation broadcast", e)
            }

            // Trigger widgets update
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisAppWidget = ComponentName(context.packageName, PayQrWidgetProvider::class.java.name)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }
}
