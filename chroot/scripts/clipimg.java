// clipimg.java — run via: droid -f clipimg.java
// Reads Android clipboard; if it holds an image (URI/intent), saves bytes to
// /sdcard/tmp/clippaste.<ext> and prints FILE:<path>. Else prints EMPTY / TEXT.
import android.content.ClipData;
import android.content.Context;

at = android.app.ActivityThread.currentActivityThread();
ctx = at.getSystemContext();
cm = ctx.getSystemService(Context.CLIPBOARD_SERVICE);
cr = ctx.getContentResolver();

clip = cm.getPrimaryClip();
if (clip == null || clip.getItemCount() == 0) {
    System.out.println("EMPTY");
    return "EMPTY";
}

desc = clip.getDescription();
mime = desc != null ? desc.getMimeType(0) : "unknown";
item = clip.getItemAt(0);
uri = item.getUri();
intent = item.getIntent();
text = item.getText();

// Case 1: direct content/file URI on the clip item
targetUri = uri;
if (targetUri == null && intent != null) {
    // Case 2: intent with EXTRA_STREAM (share-style image copy)
    targetUri = intent.getParcelableExtra(android.content.Intent.EXTRA_STREAM);
}

if (targetUri == null) {
    // Case 3: HTML clip (browser copy-image) — extract <img src> without any provider
    html = item.getHtmlText();
    if (html == null) html = item.coerceToHtmlText(ctx);
    if (html != null) {
        m = java.util.regex.Pattern.compile("<img[^>]+src\\s*=\\s*\"([^\"]+)\"").matcher(html);
        if (m.find()) {
            System.out.println("URL:" + m.group(1));
            return "URL:" + m.group(1);
        }
    }
    if (text != null) {
        // Case 4: plain text — maybe a direct image URL, or a content:// URI
        // stored as literal text (some apps copy the URI string, not a URI item)
        t = text.toString().trim();
        if (t.matches("(?i)https?://.*\\.(png|jpe?g|webp|gif)(\\?.*)?")) {
            System.out.println("URL:" + t);
            return "URL:" + t;
        }
        if (t.matches("(?i)content://.*\\.(png|jpe?g|webp|gif)(\\?.*)?")) {
            System.out.println("URI:" + t);
            return "URI:" + t;
        }
        System.out.println("TEXT:" + text.toString());
        return "TEXT";
    }
    System.out.println("EMPTY mime=" + mime);
    return "EMPTY";
}

// Resolve bytes from URI (may throw SecurityException for content:// as shell UID)
inStream = null;
try {
    inStream = cr.openInputStream(targetUri);
} catch (SecurityException se) {
    System.out.println("URI:" + targetUri + " clipmime=" + mime);
    return "URI:" + targetUri;
}
if (inStream == null) {
    System.out.println("ERROR:openInputStream-null uri=" + targetUri);
    return "ERROR";
}

// Guess extension from mime type, fall back to URI path (file:// has no mime)
type = cr.getType(targetUri);
ext = "png";
if (type != null) {
    if (type.contains("jpeg") || type.contains("jpg")) ext = "jpg";
    else if (type.contains("png")) ext = "png";
    else if (type.contains("webp")) ext = "webp";
    else if (type.contains("gif")) ext = "gif";
} else {
    seg = targetUri.getLastPathSegment();
    if (seg != null && seg.contains(".")) {
        ext = seg.substring(seg.lastIndexOf(".") + 1).toLowerCase();
    }
}

finalPath = "/sdcard/tmp/clippaste." + ext;

fout = new java.io.FileOutputStream(finalPath);
buf = new byte[8192];
n = 0;
while ((n = inStream.read(buf)) != -1) { fout.write(buf, 0, n); }
fout.close();
inStream.close();

System.out.println("FILE:" + finalPath + " mime=" + type + " clipmime=" + mime);
return "FILE:" + finalPath;
