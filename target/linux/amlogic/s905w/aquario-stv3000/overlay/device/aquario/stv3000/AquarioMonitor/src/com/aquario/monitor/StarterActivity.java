package com.aquario.monitor;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;

public final class StarterActivity extends Activity {
    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        startService(new Intent(this, MetricsOverlayService.class));
        finish();
    }
}
