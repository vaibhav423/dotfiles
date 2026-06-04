// Get the video element on the YouTube page
const vid = document.querySelector('video');

if (vid) {
    // Get the current playback time in seconds
    const t = Math.floor(vid.currentTime);
    
    // Create a URL object to easily manipulate the query parameters
    const u = new URL(window.location.href);
    u.searchParams.set('t', t);
    
    // Escape single quotes in the URL for safe shell execution
    const safeUrl = u.href.replace(/'/g, "'\\''");
    
    // Pass the modified URL to the python script via Tridactyl's native messenger
    tri.excmds.exclaim_quiet(`echo '${safeUrl}' | /home/ixdire/Water/crap/scripts/yt/addytimg.py --cookie firefox > /tmp/ytlog`);
} else {
    // Optionally notify the user if no video is found
    tri.excmds.fillcmdline_tmp(3000, "No video element found on this page.");
}
