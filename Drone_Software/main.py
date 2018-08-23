from dronekit import connect, VehicleMode, LocationGlobalRelative, LocationGlobal, Command
import time
import math
from pymavlink import mavutil
import csv
from urllib2 import urlopen

class struct(object):
	pass

# Initialize global variables
camPts = []
altitude=75*.3048
errRadius=10

# Connect to the Vehicle
print "Connecting to vehicle" 
vehicle = connect('/dev/ttyUSB0', wait_ready=True,baud=57600)

# Get some vehicle attributes (state)
print "Get some vehicle attribute values:"
print " GPS: %s" % vehicle.gps_0
print " Battery: %s" % vehicle.battery
print " Last Heartbeat: %s" % vehicle.last_heartbeat
print " Is Armable?: %s" % vehicle.is_armable
print " System status: %s" % vehicle.system_status.state
print " Mode: %s" % vehicle.mode.name    # settable

while not vehicle.is_armable:
    print " Waiting for vehicle to initialise..."
    time.sleep(1)

def readmission(fn):
    """
    Load a mission from a file into a list. The mission definition is in the Waypoint file
    format (http://qgroundcontrol.org/mavlink/waypoint_protocol#waypoint_file_format).

    This function is used by upload_mission().
    """
    print "\nReading mission from file: %s" % fn
    cmds = vehicle.commands
    missionlist=[]
    with open(fn, 'rb') as wpFile:
	wpreader = csv.reader(wpFile)
        for row in wpreader:
		newPt=struct()
		newPt.lat = float(row[0])
		newPt.lon = float(row[1])
		typ = float(row[2])
		camPts.append(newPt)
		if typ==0:
			missionlist.append(Command(0,0,0,0,16,1*(wpreader.line_num==0),1,0,0,0,0,newPt.lat,newPt.lon,altitude))
			#Command( 0, 0, 0, ln_frame, ln_command, ln_currentwp, ln_autocontinue, ln_param1, ln_param2, ln_param3, ln_param4, ln_param5, ln_param6, ln_param7)
    return missionlist

def upload_mission(aFileName):
    """
    Upload a mission from a file. 
    """
    #Read mission from file
    missionlist = readmission(aFileName)
    
    print "\nUpload mission from a file: %s" % import_mission_filename
    #Clear existing mission from vehicle
    print ' Clear mission'
    cmds = vehicle.commands
    cmds.clear()
    #Add new mission to vehicle
    for command in missionlist:
        cmds.add(command)
    print ' Upload mission'
    vehicle.commands.upload()
    print 'Upload Complete'

def get_location_metres(original_location, dNorth, dEast):
	earth_radius=6378137.0 #Radius of "spherical" earth
    #Coordinate offsets in radians
	dLat = dNorth/earth_radius
	dLon = dEast/(earth_radius*math.cos(math.pi*original_location.lat/180))

    #New position in decimal degrees
	newlat = original_location.lat + (dLat * 180/math.pi)
	newlon = original_location.lon + (dLon * 180/math.pi)
	return LocationGlobal(newlat, newlon,original_location.alt)

def get_distance_metres(aLocation1, aLocation2):
	
	dlat = aLocation2.lat - aLocation1.lat
	dlong = aLocation2.lon - aLocation1.lon
	return math.sqrt((dlat*dlat) + (dlong*dlong)) * 1.113195e5

def distance_to_current_waypoint():

	nextwaypoint = vehicle.commands.next
	if nextwaypoint==0:
		return None
	missionitem=vehicle.commands[nextwaypoint-1] #commands are zero indexed
	lat = missionitem.x
	lon = missionitem.y
	alt = missionitem.z
	targetWaypointLocation = LocationGlobalRelative(lat,lon,alt)
	distancetopoint = get_distance_metres(vehicle.location.global_frame, targetWaypointLocation)
	return distancetopoint
	
def download_mission():
    """
    Downloads the current mission and returns it in a list.
    It is used in save_mission() to get the file information to save.
    """
    print " Download mission from vehicle"
    missionlist=[]
    cmds = vehicle.commands
    cmds.download()
    cmds.wait_ready()
    for cmd in cmds:
        missionlist.append(cmd)
    return missionlist
	
def arm_and_takeoff(aTargetAltitude):

	print "Basic pre-arm checks"
    # Don't let the user try to arm until autopilot is ready
	while not vehicle.is_armable:
		print " Waiting for vehicle to initialise..."
		time.sleep(1)

        
	print "Arming motors"
    # Copter should arm in GUIDED mode
	vehicle.mode = VehicleMode("GUIDED")
	vehicle.armed = True

	while not vehicle.armed:      
		print " Waiting for arming..."
		time.sleep(5)
		vehicle.armed= True

	time.sleep(5)

	print "Taking off!"
	vehicle.simple_takeoff(aTargetAltitude) # Take off to target altitude

    # Wait until the vehicle reaches a safe height before processing the goto (otherwise the command 
    #  after Vehicle.simple_takeoff will execute immediately).
	while True:
		print " Altitude: ", vehicle.location.global_relative_frame.alt      
		if vehicle.location.global_relative_frame.alt>=aTargetAltitude*0.95: #Trigger just below target alt.
			print "Reached target altitude"
			break
		time.sleep(1)

	time.sleep(10)

# Define a function to send a command to the camera
def SendCmd(cmd):
	try:
		data = urlopen(cmd)
	except:
		print "I tried."

wifipassword = "mapsanman"

# See https://github.com/KonradIT/goprowifihack/blob/master/WiFi-Commands.mkdn
# for a list of http commands to control the GoPro cameera

on = "http://10.5.5.9/bacpac/PW?t=" + wifipassword + "&p=%01"
off = "http://10.5.5.9/bacpac/PW?t=" + wifipassword + "&p=%00"
shutter = "http://10.5.5.9/bacpac/SH?t=" + wifipassword + "&p=%01"
stop = "http://10.5.5.9/bacpac/SH?t=" + wifipassword + "&p=%00"
videoMode = "http://10.5.5.9/camera/CM?t=" + wifipassword + "&p=%00"
photoMode = "http://10.5.5.9/camera/CM?t=" + wifipassword + "&p=%01"
burstMode = "http://10.5.5.9/camera/CM?t=" + wifipassword + "&p=%02"
timeLapseMode = "http://10.5.5.9/camera/CM?t=" + wifipassword + "&p=%03"
previewOn = "http://10.5.5.9/camera/PV?t=" + wifipassword + "&p=%02"
previewOff = "http://10.5.5.9/camera/PV?t=" + wifipassword + "&p=%00"
wvga60 = "http://10.5.5.9/camera/VR?t=" + wifipassword + "&p=%00"
wvga120 = "http://10.5.5.9/camera/VR?t=" + wifipassword + "&p=%01"
v720p30 = "http://10.5.5.9/camera/VR?t=" + wifipassword + "&p=%02"
v720p60 = "http://10.5.5.9/camera/VR?t=" + wifipassword + "&p=%03"
v960p30 = "http://10.5.5.9/camera/VR?t=" + wifipassword + "&p=%04"
v960p48 = "http://10.5.5.9/camera/VR?t=" + wifipassword + "&p=%05"
v1080p30 = "http://10.5.5.9/camera/VR?t=" + wifipassword + "&p=%06"
viewWide = "http://10.5.5.9/camera/FV?t=" + wifipassword + "&p=%00"
viewMedium = "http://10.5.5.9/camera/FV?t=" + wifipassword + "&p=%01"
viewNarrow = "http://10.5.5.9/camera/FV?t=" + wifipassword + "&p=%02"
res11mpWide = "http://10.5.5.9/camera/PR?t=" + wifipassword + "&p=%00"
res8mpMedium = "http://10.5.5.9/camera/PR?t=" + wifipassword + "&p=%01"
res5mpWide = "http://10.5.5.9/camera/PR?t=" + wifipassword + "&p=%02"
res5mpMedium = "http://10.5.5.9/camera/PR?t=" + wifipassword + "&p=%03"
noSound = "http://10.5.5.9/camera/BS?t=" + wifipassword + "&p=%00"
sound70 = "http://10.5.5.9/camera/BS?t=" + wifipassword + "&p=%01"
sound100 = "http://10.5.5.9/camera/BS?t=" + wifipassword + "&p=%02"		
	
import_mission_filename = 'flight01.csv'

#Upload mission from file
upload_mission(import_mission_filename)

arm_and_takeoff(altitude)

print "Pointing Gimbal Straight Down"
#Point the gimbal straight down
vehicle.gimbal.rotate(-90, 0, 0)
print " Gimbal Pitch: %s" % vehicle.gimbal.pitch
SendCmd(on)
time.sleep(5)
SendCmd(photoMode)

print "Starting mission"
# Reset mission set to first (0) waypoint
vehicle.commands.next=0

# Set mode to AUTO to start mission
vehicle.mode = VehicleMode("AUTO")

with open('Pictured_Waypoints.csv','wb') as csvfile:
	writer=csv.writer(csvfile)
	while True:
		for wp in camPts:
			if get_distance_metres(vehicle.location.global_frame,wp)<errRadius:
				SendCmd(shutter)
				print "Cheese!"
				writer.writerow([vehicle.location.global_frame.lat,vehicle.location.global_frame.lon])
		nextwaypoint=vehicle.commands.next
		print 'Distance to waypoint (%s): %s' % (nextwaypoint, distance_to_current_waypoint())
		print " Gimbal Pitch: %s" % vehicle.gimbal.pitch
		time.sleep(1)

print 'Return to launch'
vehicle.mode = VehicleMode("RTL")

SendCmd(off)

#Close vehicle object before exiting script
print "Close vehicle object"
vehicle.close()
