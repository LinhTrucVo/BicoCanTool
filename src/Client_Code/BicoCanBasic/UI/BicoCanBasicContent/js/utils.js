// Loads a JSON file synchronously and returns the parsed object, or null on failure
function loadUIMessageInterface(url) {
    var request = new XMLHttpRequest();
    request.open("GET", url, false);
    request.send();
    if (request.responseText.length > 0) {
        return JSON.parse(request.responseText);
    } else {
        console.log("Failed to load " + jsonFileName + " from: " + url + " (status=" + request.status + ")");
        return null;
    }
}
