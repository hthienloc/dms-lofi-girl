.pragma library

function fetchFromChannel(proc, limit, callback) {
    const channelUrl = "https://www.youtube.com/@LofiGirl/videos";
    // Fetch title, id, thumbnail and duration (in seconds)
    const cmd = `/usr/bin/yt-dlp --cookies-from-browser firefox --js-runtimes node --flat-playlist --print "%(title)s|%(id)s|%(thumbnail)s|%(duration)s" --playlist-end 30 ${channelUrl} || /usr/bin/yt-dlp --cookies-from-browser chrome --js-runtimes node --flat-playlist --print "%(title)s|%(id)s|%(thumbnail)s|%(duration)s" --playlist-end 30 ${channelUrl}`;
    
    proc.runCommand("fetch-lofi", ["bash", "-c", cmd], (output, exitCode) => {
        if (exitCode !== 0 || !output) {
            callback([], "Failed to fetch content or empty output");
            return;
        }

        const lines = output.trim().split("\n");
        const items = lines.map(line => {
            const parts = line.split("|");
            if (parts.length < 2) return null;
            
            const id = parts[1];
            const title = parts[0];
            const duration = parseFloat(parts[3] || 0);
            
            // Filter: 1 min < duration < 2 hours (7200 seconds)
            if (duration < 60 || duration > 7200) return null;

            let thumb = (parts.length >= 3 && parts[2] !== "NA") ? parts[2] : `https://i.ytimg.com/vi/${id}/mqdefault.jpg`;
            
            // Helper to format duration string
            const mins = Math.floor(duration / 60);
            const secs = Math.floor(duration % 60);
            const durationStr = `${mins}:${secs.toString().padStart(2, '0')}`;

            return {
                id: id,
                name: title,
                url: `https://www.youtube.com/watch?v=${id}`,
                thumb: thumb,
                duration: durationStr
            };
        }).filter(m => m !== null).slice(0, limit); // Apply requested limit after filtering

        callback(items, null);
    }, 0);
}

function fetchMixes(proc, callback) {
    fetchFromChannel(proc, 10, callback);
}

function fetchLatestVideos(proc, callback) {
    fetchFromChannel(proc, 5, callback);
}

function checkDownloads(proc, soundsDir, callback) {
    // List files with size in KB to identify partial downloads
    const cmd = `mkdir -p '${soundsDir}' && find '${soundsDir}' -name "*.mp3" -size +1024k -printf "%f\\n"`;
    proc.runCommand("check-lofi", ["sh", "-c", cmd], (output, exitCode) => {
        let map = {};
        if (exitCode === 0 && output) {
            let files = output.trim().split("\n");
            console.log("Lofi Girl: Checking downloads in", soundsDir, "Found valid files:", files.length);
            for (let f of files) {
                if (f.endsWith(".mp3")) {
                    let id = f.replace(".mp3", "");
                    map[id] = true;
                }
            }
        }
        callback(map);
    }, 0);
}
