package com.opc.stella

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class RecentUpdatesWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.recent_updates_widget_layout)

            val count = widgetData.getInt("recent_count", 0)

            views.setTextViewText(
                R.id.widget_episode_count,
                if (count > 0) "$count new" else "No new episodes"
            )

            for (i in 0 until 3) {
                val title = widgetData.getString("recent_${i}_title", "") ?: ""
                val podcast = widgetData.getString("recent_${i}_podcast", "") ?: ""

                val titleViewId = when (i) {
                    0 -> R.id.widget_ep1_title
                    1 -> R.id.widget_ep2_title
                    2 -> R.id.widget_ep3_title
                    else -> 0
                }
                val podcastViewId = when (i) {
                    0 -> R.id.widget_ep1_podcast
                    1 -> R.id.widget_ep2_podcast
                    2 -> R.id.widget_ep3_podcast
                    else -> 0
                }
                val rowViewId = when (i) {
                    0 -> R.id.widget_ep1_row
                    1 -> R.id.widget_ep2_row
                    2 -> R.id.widget_ep3_row
                    else -> 0
                }

                if (title.isNotEmpty() && rowViewId != 0) {
                    views.setTextViewText(titleViewId, title)
                    views.setTextViewText(podcastViewId, podcast)
                    views.setViewVisibility(rowViewId, View.VISIBLE)
                } else if (rowViewId != 0) {
                    views.setViewVisibility(rowViewId, View.GONE)
                }
            }

            val launchIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
