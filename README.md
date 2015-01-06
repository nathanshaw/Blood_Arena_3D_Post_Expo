shooter3D
=========
NOTES:

IN ORDER TO GET WORKING FOLLOW THE FOLLOWING STEPS :

1) Run the initalize file found in the ChucK folder in Mini Audicle or Terminal. (this sets up the OSC routing and audio)
2) Run the "PlayerAvatarBroadcasterPrefixBased" processing scetch
3) Run "PlayerAvatarTerrainTest" this will initalize the game for you
4)
5)

CONTROLS FOR KEYBOARD:

    -w,s - change move speed
	-spacebar - stop moving
	-click mouse - explosion
	-dragging mouse while clicking - move camera
	-q - axe
	-e -laser


case 'C': disconnect(lport, myprefix); connect(lport, myprefix); break;
case 'f': disconnect(lport, myprefix); connected = false; break;
case 'R': roster.print(); break;
case 'M': map.print(); break;
case 'I': loop(); cam.spawnCamera(TEMP_SPAWN, new PVector(0, 0, 0)); break; //randomSpawnCamera(5000); break;
case 'v': cam.living = false; sendKill(myprefix, myLocation); sendKill(myprefix, myBroadcastLocation); break; //cam.living = false; killCamera(); (myprefix); break;

//temp testing variables
case 'w': joystick.x = 2; break;
case 'x': joystick.x = -2; break;
case 'a': joystick.z = -2; break;
case 'd': joystick.z = 2; break;
case 's': joystick.x = 0; joystick.z = 0; break;

case 'j': acc.x = -1; break;
case 'k': acc.x = 0; acc.y = 0; break;
case 'l': acc.x = 1; break;
case 'u': acc.y = 1; break;
case 'm': acc.y = -1; break;
case 'D': ADEBUG = 0; break;
case 'A': ADEBUG = 1; break;
case 'P': newPlayer();break;
case 'O': sendExplosion(); break;
case '[': initTextures(); break;
