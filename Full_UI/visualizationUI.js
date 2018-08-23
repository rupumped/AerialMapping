var photo;
var GPSPoints;
var overlay;
var reader = new FileReader();

function getPhoto() {
    photo = window.URL.createObjectURL(document.getElementById("stitchedPhoto").files[0]);
    document.getElementById("photoText").innerHTML = "Uploaded";
    if (GPSPoints != null){
        updateOverlay();
    }
}
function getGPS() {
    reader.readAsText(document.getElementById("GPSpoints").files[0]);
    reader.onload = function(evt){
        GPSPoints = evt.target.result;
        document.getElementById("GPSText").innerHTML = "Uploaded";
        if (photo != null){
        updateOverlay();
        }
    }
}
function updateOverlay(){
    var bounds = GPSPoints.split("\n");
    var imageBounds = {
        north: Number(bounds[0]),
        south: Number(bounds[1]),
        east: Number(bounds[2]),
        west: Number(bounds[3])
    };
    overlay = new google.maps.GroundOverlay(photo, imageBounds);
}
