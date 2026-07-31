package de.eye_interactive.atvl.chromebrowser;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;

public final class ChromeLauncherActivity extends Activity {
    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);

        Intent chrome = getPackageManager().getLaunchIntentForPackage("com.android.chrome");
        if (chrome != null) {
            chrome.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(chrome);
        }
        finish();
    }
}
