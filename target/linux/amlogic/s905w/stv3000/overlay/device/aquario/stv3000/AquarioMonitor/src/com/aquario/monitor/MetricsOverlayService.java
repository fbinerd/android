package com.aquario.monitor;

import android.app.ActivityManager;
import android.app.Service;
import android.content.ComponentName;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Handler;
import android.os.IBinder;
import android.view.Gravity;
import android.view.WindowManager;
import android.widget.TextView;

import java.io.BufferedReader;
import java.io.FileReader;
import java.util.List;

public final class MetricsOverlayService extends Service {
    private static final String LAUNCHER_PACKAGE = "com.google.android.tvlauncher";
    private static final String METRICS_FILE = "/data/system/aquario_metrics";

    private final Handler handler = new Handler();
    private WindowManager windowManager;
    private TextView metricsView;
    private boolean attached;

    private final Runnable refresh = new Runnable() {
        @Override
        public void run() {
            boolean onHome = isLauncherForeground();
            if (onHome && !attached) {
                windowManager.addView(metricsView, createLayoutParams());
                attached = true;
            } else if (!onHome && attached) {
                windowManager.removeView(metricsView);
                attached = false;
            }

            if (attached) {
                metricsView.setText(readMetrics());
            }
            handler.postDelayed(this, 2000);
        }
    };

    @Override
    public void onCreate() {
        super.onCreate();
        windowManager = getSystemService(WindowManager.class);
        metricsView = new TextView(this);
        metricsView.setTextColor(Color.WHITE);
        metricsView.setTextSize(16);
        metricsView.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
        metricsView.setGravity(Gravity.CENTER);
        metricsView.setPadding(dp(14), dp(7), dp(14), dp(7));

        GradientDrawable background = new GradientDrawable();
        background.setColor(0xCC202124);
        background.setCornerRadius(dp(6));
        background.setStroke(dp(1), 0xFF4FC3F7);
        metricsView.setBackground(background);
        handler.post(refresh);
    }

    @Override
    public void onDestroy() {
        handler.removeCallbacks(refresh);
        if (attached) {
            windowManager.removeView(metricsView);
            attached = false;
        }
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        return START_STICKY;
    }

    private WindowManager.LayoutParams createLayoutParams() {
        WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                        | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                        | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                android.graphics.PixelFormat.TRANSLUCENT);
        params.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
        params.y = dp(18);
        params.setTitle("Aquario performance monitor");
        return params;
    }

    private boolean isLauncherForeground() {
        ActivityManager manager = getSystemService(ActivityManager.class);
        List<ActivityManager.RunningTaskInfo> tasks = manager.getRunningTasks(1);
        if (tasks == null || tasks.isEmpty()) {
            return false;
        }
        ComponentName top = tasks.get(0).topActivity;
        return top != null && LAUNCHER_PACKAGE.equals(top.getPackageName());
    }

    private String readMetrics() {
        try (BufferedReader reader = new BufferedReader(new FileReader(METRICS_FILE))) {
            String value = reader.readLine();
            return value == null ? "CPU --  RAM --  GPU --" : value;
        } catch (Exception ignored) {
            return "CPU --  RAM --  GPU --";
        }
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
