package com.namecard.mapae

import android.content.Context
import org.json.JSONObject

/**
 * Flutter SharedPreferences 에 저장된 명함 캐시를 읽어 들이는 헬퍼.
 *
 * Flutter 측 키:
 *   "flutter.caller_id_cache_v1" -> JSON string of { normalizedPhone: { name, company, ... } }
 */
object CallerCache {
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val CACHE_KEY = "flutter.caller_id_cache_v1"

    /**
     * 들어온 전화번호를 정규화하고 캐시에서 매칭되는 명함 정보를 반환합니다.
     * 정확 매칭 우선, 없으면 끝 8자리 매칭 (국가 코드 차이 대응).
     */
    fun lookup(context: Context, rawNumber: String?): JSONObject? {
        if (rawNumber.isNullOrBlank()) return null
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val cacheJson = prefs.getString(CACHE_KEY, null) ?: return null
        val map: JSONObject = try {
            JSONObject(cacheJson)
        } catch (e: Exception) {
            return null
        }

        val normalized = normalize(rawNumber)
        if (normalized.isEmpty()) return null

        if (map.has(normalized)) {
            return map.optJSONObject(normalized)
        }

        if (normalized.length >= 8) {
            val suffix = normalized.substring(normalized.length - 8)
            val keys = map.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                if (key.length >= 8 && key.endsWith(suffix)) {
                    return map.optJSONObject(key)
                }
            }
        }
        return null
    }

    /** Flutter 측 normalizePhone 과 동일한 규칙. */
    fun normalize(raw: String): String {
        if (raw.isEmpty()) return ""
        val sb = StringBuilder()
        for (c in raw) {
            if (c.isDigit() || c == '+') sb.append(c)
        }
        var s = sb.toString()
        if (s.startsWith("+82")) {
            s = "0" + s.substring(3)
        } else if (s.startsWith("82") && s.length > 10) {
            s = "0" + s.substring(2)
        }
        return s.replace("+", "")
    }
}
