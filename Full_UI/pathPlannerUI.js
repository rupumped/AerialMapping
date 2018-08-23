var csvContent;
var waypoints;
var activePoly=[];
var activeHome=[];
var activeLatLines=[];
var activeLngLines=[];
var activeGrid=[];
var rectangles=[];
var drawingManager;
var photo;
var GPSPoints;
var overlay;
var reader = new FileReader();
var map;

function initMap() { //google maps initialization
  map = new google.maps.Map(document.getElementById('map'), {
    center: {lat: 33.777807, lng: -84.3986074,}, //center @ GT
    zoom: 15
  });

  drawingManager = new google.maps.drawing.DrawingManager({ //initialize drawing toolbar
    drawingMode: google.maps.drawing.OverlayType.MARKER,
    //drawingControl: true, //set true to show toolbar
    drawingControl: false,
    drawingControlOptions: {
      position: google.maps.ControlPosition.TOP_CENTER,
      drawingModes: [
        google.maps.drawing.OverlayType.MARKER,
        google.maps.drawing.OverlayType.CIRCLE,
        google.maps.drawing.OverlayType.POLYGON,
        google.maps.drawing.OverlayType.POLYLINE,
        google.maps.drawing.OverlayType.RECTANGLE
      ]
    },
  });
  drawingManager.setMap(map);
  
  google.maps.event.addListener(drawingManager, 'polygoncomplete', function(polygon) { //callback for grid creation on polygon draw
    createGrid(polygon,map);
    activePoly.push(polygon);
  });

  google.maps.event.addListener(drawingManager, 'markercomplete', function(marker) { //callback for home point storage on click
    marker.setMap(null); //don't display click location -- marker will snap to grid
    setHome(marker,map);
  })
}
function startPath() { //begins path planning sequence
  //clear all global variables, hide all drawing objects
  activeGrid.forEach(function(infoArray){
    infoArray.setMap(null);
  });
  activeGrid = [];
  activeLatLines = [];
  activeLngLines = [];
  activePoly.forEach(function(infoArray){
    infoArray.setMap(null);
  })
  activePoly=[];
  activeHome.forEach(function(infoArray){
    infoArray.setMap(null);
  })
  activeHome=[];
  rectangles.forEach(function(infoArray){
    infoArray.setMap(null);
  });
  rectangles=[];
  //instruct user to draw desired polygon
  alert("Draw a polygon for imaging");
  drawingManager.setDrawingMode(google.maps.drawing.OverlayType.POLYGON);
}
function createGrid(polygon,map) {
  //create bounding box of user-drawn polygon
  var len = polygon.getPath().getLength();
  var northCoord = polygon.getPath().getAt(0).lat();
  var southCoord = polygon.getPath().getAt(0).lat();
  var eastCoord = polygon.getPath().getAt(0).lng();
  var westCoord = polygon.getPath().getAt(0).lng();
  for (var i = 1; i<len; i++) {
    var currLat = polygon.getPath().getAt(i).lat();
    var currLng = polygon.getPath().getAt(i).lng();
    if (currLat > northCoord) { northCoord = currLat; } //find farthest northern point
    if (currLat < southCoord) { southCoord = currLat; } //find farthest southern point
    if (currLng > eastCoord) { eastCoord = currLng; } //find farthest eastern point
    if (currLng < westCoord) { westCoord = currLng; } //find farthest western point
  }
  var boundingBoxCoords = [
    new google.maps.LatLng({lat: northCoord, lng: eastCoord}), //NE corner
    new google.maps.LatLng({lat: northCoord, lng: westCoord}), //NW corner
    new google.maps.LatLng({lat: southCoord, lng: westCoord}), //SW corner
    new google.maps.LatLng({lat: southCoord, lng: eastCoord}), //SE corner
    new google.maps.LatLng({lat: northCoord, lng: eastCoord})
  ];
  var boundingBox = new google.maps.Polyline({ //create bounding box polyline
    path: boundingBoxCoords,
  });
  //boundingBox.setMap(map); //uncomment this line to display bounding box
  activeGrid.push(boundingBox); //push bounding box handle to grid array

  //grid fill
  var picDims = picSize(); //calc. picture size from camera params
  var picHeight = picDims[0];
  var picWidth = picDims[1];
  var areaHeight = distance(new google.maps.LatLng({lat:northCoord, lng:eastCoord}),new google.maps.LatLng({lat:southCoord,lng:eastCoord})); //calculate height of bounding box in m
  var areaWidth = distance(new google.maps.LatLng({lat:northCoord, lng:eastCoord}), new google.maps.LatLng({lat:northCoord, lng:westCoord})); //calculate width of BB in m
  //create lines of constant latitude/longitude
  var NWCorner = new google.maps.LatLng({lat:northCoord, lng: westCoord}); //start lines @ NW corner
  var constLatLine = [NWCorner];
  var constLngLine = [NWCorner];
  for (var i = 1; i < Math.ceil(areaHeight/picHeight)+1; i++){ //divide height into necessary lat lines, store lats.
    constLatLine[i] = newPoint(constLatLine[i-1],180,picHeight);
    activeLatLines.push(constLatLine[i]); //push line to array for "snap" function of home point
  }
  for (var i = 1; i < Math.ceil(areaWidth/picWidth)+1; i++){ //divide width into necessary lng lines, repeat
    constLngLine[i] = newPoint(constLngLine[i-1],90,picWidth);
    activeLngLines.push(constLngLine[i]);
  }
  //create Lat/Lng line objects for display on map
  for (var i = 0; i < constLatLine.length; i++){
    var currPath = [
      constLatLine[i],
      new google.maps.LatLng({lat: constLatLine[i].lat(), lng: eastCoord})
    ];
    var currLine = new google.maps.Polyline({
      path: currPath,
      strokeColor: "#FF0000",
      strokeOpacity: 0.5,
      strokeWeight: 5
    });
    //currLine.setMap(map); //set this true to display lat lines
    activeGrid.push(currLine); //store handle
  }
  for (var i = 0; i < constLngLine.length; i++){
    var currPath = [
      constLngLine[i],
      new google.maps.LatLng({lat: southCoord, lng: constLngLine[i].lng()})
    ];
    var currLine = new google.maps.Polyline({
      path: currPath,
      strokeColor: "#FF0000",
      strokeOpacity: 0.5,
      strokeWeight: 5
    });
    //currLine.setMap(map); //set this true to display lng lines
    activeGrid.push(currLine); //store handle
  }
  //Find picture locations + create rectangle object for display
  var latDiff = Math.abs(newPoint(constLatLine[0],180,picHeight/2).lat()-NWCorner.lat()); //calculate picture height in degrees
  var lngDiff = Math.abs(newPoint(constLngLine[0],90,picWidth/2).lng()-NWCorner.lng()); //calculate picture width in degrees
  waypoints = [];
  var count = 0;
  for (var i = 0; i < constLngLine.length; i++) {
    for (var j = 0; j < constLatLine.length; j++){
      var currLoc = new google.maps.LatLng({lat:constLatLine[j].lat(),lng:constLngLine[i].lng()}); //current grid intersection point
      var southCenter = newPoint(currLoc,180,picHeight/2);
      var northCenter = newPoint(currLoc,0,picHeight/2);
      //find corners of picture
      var currNWCorner = newPoint(northCenter,270,picWidth/2);
      var currNECorner = newPoint(northCenter,90,picWidth/2);
      var currSWCorner = newPoint(southCenter,270,picWidth/2);
      var currSECorner = newPoint(southCenter,90,picWidth/2);
      //determine if center of picture, or any corner, is enclosed by polygon
      if (google.maps.geometry.poly.containsLocation(currLoc,polygon)||google.maps.geometry.poly.containsLocation(currNWCorner,polygon)||google.maps.geometry.poly.containsLocation(currNECorner,polygon)||google.maps.geometry.poly.containsLocation(currSWCorner,polygon)||google.maps.geometry.poly.containsLocation(currSECorner,polygon)) {
        //if contained, push current intersection to waypoints list
        waypoints.push(currLoc);
        //create rectangle for picture display
        var rectangle = new google.maps.Rectangle({
          bounds: {
           north: currLoc.lat()+latDiff,
           south: currLoc.lat()-latDiff,
           east: currLoc.lng()+lngDiff,
           west: currLoc.lng()-lngDiff
           } 
        });
        //rectangle.setMap(map); //uncomment this to show picture rectangles
        rectangles.push(rectangle); //store rectangle handles
      }
    }
  }
  alert("Click to set home point"); //grid creation complete, prompt user selection of home point
  drawingManager.setDrawingMode(google.maps.drawing.OverlayType.MARKER);
}
function setHome(marker, map){ //allows user to select a "home point" which will snap to the grid
  if (!google.maps.geometry.poly.containsLocation(marker.getPosition(),activePoly[0])){
    alert("Please select a home point inside the polygon."); //home point must be inside polygon
  } else {
    //find waypoint closest to user-selected point
    var homeLat = Infinity;
    var homeLng = Infinity;
    activeLngLines.forEach(function(infoArray){ //find closest lng on grid
      var newLng = infoArray.lng();
      if (Math.abs(marker.getPosition().lng()-newLng)<Math.abs(marker.getPosition().lng()-homeLng)){
        homeLng = newLng;
      }
    });
    activeLatLines.forEach(function(infoArray){ //find closest lat on grid
      var newLat = infoArray.lat();
      if (Math.abs(marker.getPosition().lat()-newLat)<Math.abs(marker.getPosition().lat()-homeLat)){
        homeLat = newLat;
      }
    });
    var snappedPos = new google.maps.LatLng({lat: homeLat, lng: homeLng}); //home point snapped to grid
    var newMarker = new google.maps.Marker({ //display "snapped" home on map
      position: snappedPos,
      map: map
    })
    activeHome.push(newMarker);
  }
}
function downloadCSV(){ //function to download grid CSV + home point for path planning algorithm
  csvContent = "data:text/csv;charset=utf-8,";
  waypoints.forEach(function(infoArray, index){ //format waypoints in csv string for storage
    csvContent += infoArray.lat() + ", " + infoArray.lng() + "\n";
  });
  csvContent += activeHome[0].getPosition().lat() + ", " + activeHome[0].getPosition().lng() + "\n"; //append home point as final entry
  var encodedUri = encodeURI(csvContent);
  var link = document.createElement("a"); //create hidden link for download
  link.setAttribute("href", encodedUri);
  link.setAttribute("download", "waypoints.csv");
  document.body.appendChild(link); //attach hidden link to webpage
  link.click(); //click hidden link to download
}
var picSize = function(){ //function to calculate picture size in m from user params
  var focalLength = document.getElementById('focal').value; //get focal length
  if (focalLength == null || focalLength=="") { focalLength = 9.5}; //if user has not input value, use normal GoPro values (saves time)
  var WD = document.getElementById('WD').value; //get working distance
  if (WD == null || WD=="") {WD = 200}; //use normal value
  var sensorHeight = document.getElementById('sensorHeight').value; //get sensor height
  if (sensorHeight == null || sensorHeight=="") {sensorHeight = 1}; //etc
  var sensorWidth = document.getElementById('sensorWidth').value; //get sensor width
  if (sensorWidth == null || sensorWidth=="") {sensorWidth = 2.3};
  var overlap = document.getElementById('overlap').value; //get overlap percentage
  if (overlap == null || overlap=="") {overlap = 80};
  focalLength = 0.0393701*focalLength; //convert to in
  WD = 12*WD; //convert to in
  var PMAG = focalLength/WD; //camera eqns
  var picHeight = sensorHeight*(1-(overlap/100))/PMAG;
  picHeight = picHeight*0.0254; //convert to m
  var picWidth = sensorWidth*(1-(overlap/100))/PMAG;
  picWidth = picWidth*.0254; //convert to m
  return [picHeight, picWidth]; //return picture height/width in m
}
var distance = function(coord1, coord2){ //HAVERSINE FORMULA -- calculate great circle distance between two lat/lng points
  //assumes spherical earth, 0.3% max error even at small distances
  var lat1 = coord1.lat();
  var lon1 = coord1.lng();
  var lat2 = coord2.lat();
  var lon2 = coord2.lng();
  var R = 6371000; // metres
  var φ1 = lat1.toRadians();
  var φ2 = lat2.toRadians();
  var Δφ = (lat2-lat1).toRadians();
  var Δλ = (lon2-lon1).toRadians();

  var a = Math.sin(Δφ/2) * Math.sin(Δφ/2) + Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ/2) * Math.sin(Δλ/2); //haversine formula
  var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c; //return distance in m
}
var newPoint = function(current, bearing, d){ //given a bearing and distance, generate new lat/lng point from an old one
  var lat1 = current.lat();
  var lon1 = current.lng();
  var theta = bearing.toRadians();
  var φ1 = lat1.toRadians();
  var λ1 = lon1.toRadians();
  var R = 6371000; // metres
  var φ2 = Math.asin( Math.sin(φ1)*Math.cos(d/R) + Math.cos(φ1)*Math.sin(d/R)*Math.cos(theta) );
  var λ2 = λ1 + Math.atan2(Math.sin(theta)*Math.sin(d/R)*Math.cos(φ1), Math.cos(d/R)-Math.sin(φ1)*Math.sin(φ2));
  return new google.maps.LatLng({lat:φ2.toDegrees(),lng:λ2.toDegrees()});
}
Number.prototype.toRadians = function() {
return this * Math.PI / 180;
}
Number.prototype.toDegrees = function() {
  return this * 180 / Math.PI;
}
//Visualization UI
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
    overlay.setMap(map)
}
