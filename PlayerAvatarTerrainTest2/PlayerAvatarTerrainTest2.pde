import oscP5.*;
import netP5.*;
import papaya.*;
import java.util.*; 
import processing.video.*;
//import processing.opengl.*;
import shapes3d.*;
import shapes3d.utils.*;
import shapes3d.animation.*;

int ADEBUG = 0;
PVector TEMP_SPAWN;

///////////****OSC****\\\\\\\\\\\\\
OscP5 pos_in;
OscP5 oscP5;
int lport = 12007;
int coutport = 14000;
int cinport = 14001;
int bcport = 32000;
String BROADCAST_LOCATION = "10.0.1.2.";
//String BROADCAST_LOCATION = "169.254.78.169";
NetAddress myLocation;
NetAddress myBroadcastLocation; 
String myprefix = "/twerpz";
boolean connected = true;

PApplet APPLET = this;
Map map;
Camera cam;
Roster roster;
Terrain terrain;

//-----CONSTANTS for Terrain
int X_SIZE = 1001;
int Z_SIZE = 1001;
int TERRAIN_SLICES = 16;
float TERRAIN_HORIZON = 300;
float TERRAIN_AMP = 70;

//-----CONSTANTS for Objects
int height_OFFSET = 50;

//-----CONSTANTS for Players
float STRIKE_RADIUS = 50;
float DISTANCE_FROM_PLAYER = 500;
float SHOTS = 0;

PVector [] COLORS;

//for texture syncing
int texCycle = (int)random(0,5);

//*******Texture Arrays*******\\ 

String[] respawnTex = new String[] {
  "newKS1.png", "newKS1.png", "newKS1.png"
};
String[] laserTex = new String[] {
  "laser1.jpg", "laser2.jpg", "laser3.JPG", "laser4.jpg", "laser1.jpg", "laser2.jpg"
};
//texture order is fire/ice/glass/space/abstract repeating
String[] terrainTex = new String[] {//textures for terrain
  "lava1.jpg",  "elec1.jpg", "laser3.JPG", "sky14.jpg"
};

String[] skyTex = new String[] {//could load fog as background
  "laser3.JPG", "axe5.jpg", "wires1.jpg", "snow1.jpg", "fire1.jpg", "metal2.jpg"
};

PImage laserTexCur;
PImage terrainTexCur;
PImage skyTexCur;
PImage killScreen;

//PShader lines;
//PShader noise;
PShader SHADER_NOISE;
PShader SHADER_LASER;
PShader SHADER_CROSSHAIR;
PShader SHADER_DEATH;
PShader SHADER_MELEE;

PVector acc = new PVector(0, 0, 0); //can we set Camera directly from OSC?
PVector joystick = new PVector(0, 0, 0);
/*
boolean sketchFullScreen(){
 return true; 
}
*/
void setup() 
{
  smooth();
  //size(900, 900, P3D);
  size(displayWidth, displayHeight, P3D);
  frameRate(24);
  
  pos_in = new OscP5(this, cinport);
  pos_in.plug(this, "accelData", "/nunchuck/accel");
  pos_in.plug(this, "joystickData", "/nunchuck/joystick");
  pos_in.plug(this, "chuckRespawn", "/chuck/init");
  pos_in.plug(this,"cButtonPing", "/nunchuck/Cbutton");
  pos_in.plug(this,"zButtonPing", "/nunchuck/Zbutton");

  
  oscP5 = new OscP5(this,lport);
  
  myLocation = new NetAddress("127.0.0.1", coutport);
  myBroadcastLocation = new NetAddress(BROADCAST_LOCATION, bcport);
 
  
  roster = new Roster();
  map = new Map(1001, 1001);
  cam = new Camera(this);
  terrain = new Terrain(APPLET, TERRAIN_SLICES, X_SIZE, TERRAIN_HORIZON);
  terrain.usePerlinNoiseMap(-TERRAIN_AMP, TERRAIN_AMP, 2.125f, 2.125f);
  terrain.cam = cam.cam;
  
  initTextures();
  COLORS = shiftGlobalColors();
  
  SHADER_NOISE = loadShader("noisenormalizedfrag.glsl");
  SHADER_LASER = loadShader("sinelines2frag.glsl");
  SHADER_CROSSHAIR = loadShader("circlefrag.glsl");
  SHADER_DEATH = loadShader("circletexdeathfrag.glsl");
  SHADER_MELEE = loadShader("pixelfrag.glsl");
  
  println("width:", width);
  println("displayWidth:", displayWidth);
  TEMP_SPAWN = new PVector(0, 0, -500);
}

void draw() 
{
  
  if ( (cam.living == false) || (connected == false) )
  {
    background(0);
    
    killCamera(); //should have this display death for a certain number of seconds, I guess, and return to trigger the next thing.
    noLoop(); 
    
  }
  else
  {
    background(0);
    lights(); //unneccessary, this just calls the default.
    
    COLORS = shiftGlobalColors();
    
    SHADER_NOISE.set("time", (millis() * .001));
    SHADER_NOISE.set("resolution", (float) width * random(1, 1), (float) height * random(1, 1)); //these values reproduce the site's effect
    SHADER_NOISE.set("alpha", .8); 
    SHADER_NOISE.set("floor", .8);
    SHADER_NOISE.set("ceil", .8);
    shader(SHADER_NOISE);
    terrain.draw();
    map.update();
    map.display();
    
    resetShader();
    
    //
    //println("pos", cam.pos);
    //println("eye", cam.cam.eye());
    cam.display();
    cam.look(acc.x, acc.y);
    cam.move(joystick);
    //renderGlobe();
    PVector next = adjustY(PVector.add(cam.pos, cam.move), terrain, 0);
    if (map.checkBounds(next) == -1)
    { 
      cam.update();
      cam.adjustToTerrain(terrain, -30); //should be fine, because it only alters the eye, which is overwritten by pos. gottabe after update for that reason. if you wanted to update pos, or an object, use Terrain.adjustPosition.
      //println(cam.pos);
      sendPos(cam.pos.x, 0, cam.pos.z, 0, cam.rot.y, 0);
      float odist = map.getDistFromAvatar(cam.pos, DISTANCE_FROM_PLAYER);
      if (odist < DISTANCE_FROM_PLAYER) { sendDist(odist); }
    }
    else
    {
      println("boundary!", cam.pos);
      cam.move(new PVector(0, 0, 0));
    }
  }
  
  
}

//-----OSC SEND FUNCTIONS
void connect(int ilport, String ipre) //should do all this crap automatically before players "spawn" because we ought to have bugs in this worked out before players are allowed to see anything
{
  OscMessage m = new OscMessage("/server/connect");
  m.add(ilport); 
  m.add(ipre);
  oscP5.send(m, myBroadcastLocation);
}

void disconnect(int ilport, String ipre)
{
  roster.clear();
  map.clear();
  OscMessage m = new OscMessage("/server/disconnect");
  m.add(ilport); 
  m.add(ipre);
  oscP5.send(m, myBroadcastLocation);
}


void sendPos(float ix, float iy, float iz, float irx, float iry, float irz) //+ rotation
{
  OscMessage ocoor = new OscMessage(myprefix + "/pos");
  ocoor.add(ix);
  ocoor.add(iy);
  ocoor.add(iz);
  ocoor.add(irx);
  ocoor.add(iry);
  ocoor.add(irz);
  oscP5.send(ocoor, myBroadcastLocation);
}

void sendShot(PVector ipos, PVector iaim, NetAddress ilocation)
{
  OscMessage ocoor = new OscMessage(myprefix + "/shot");
  ocoor.add(ipos.x);
  ocoor.add(ipos.y);
  ocoor.add(ipos.z);
  ocoor.add(iaim.x);
  ocoor.add(iaim.y);
  ocoor.add(iaim.z);
  oscP5.send(ocoor, ilocation);
}

void sendBlankPing(NetAddress ilocation)
{
  OscMessage oping = new OscMessage(myprefix + "/blank");
  oping.add(1);
  oscP5.send(oping, ilocation);
}

void sendKill(String iaddr, NetAddress ilocation)
{
  OscMessage oaddr = new OscMessage(myprefix + "/kill");
  oaddr.add(iaddr);
  oscP5.send(oaddr, ilocation);
}

void sendMelee(int istatus, NetAddress ilocation)
{
  OscMessage oint = new OscMessage(myprefix + "/melee");
  oint.add(istatus);
  oscP5.send(oint, ilocation);
}

void sendDist(float idist)
{
  OscMessage odist = new OscMessage(myprefix + "/distance");
  odist.add(idist);
  oscP5.send(odist, myLocation);
}

void newPlayer() 
{
  OscMessage newP = new OscMessage("/arena/newPlayer");
  newP.add(1);
  oscP5.send(newP, myLocation);
}

void sendExplosion() 
{ //maybe redundant, only happens on kill and death
  OscMessage sendExplosion = new OscMessage(myprefix + "/explosion");
  sendExplosion.add(1);
  oscP5.send(sendExplosion, myLocation);
  println("explosion Trigger sent to Chuck");
}

//-----OSC FROM CHUCK
public void cButtonPing(int ping){
  
      if (SHOTS <= 0) { println("out of ammo!"); sendBlankPing(myLocation); }
      else 
      { 
        SHOTS--;
        cam.laser = 1.0;
          sendShot(cam.pos, cam.aim, myLocation);
        sendShot(cam.pos, cam.aim, myBroadcastLocation);
        int indx = map.getIndexByAngle(cam.pos, cam.aim);
        if (map.isAvatar(indx))
        {
          Avatar a = (Avatar) map.objects.get(indx);
          Player p = a.player;
          if ( (a.kill() != -1)  && (p != null ) )
          {
            sendKill(p.prefix, myLocation);
            sendKill(p.prefix, myBroadcastLocation);
          }
        
        }
        else 
        {
          println("shootin' blanks!");
        }
    }
}

public void zButtonPing(int ping){
      sendMelee(1, myLocation);
      sendMelee(1, myBroadcastLocation);
      int indx = map.checkBounds(cam.pos, STRIKE_RADIUS);
      if (map.isAvatar(indx))
      {
        Avatar a = (Avatar) map.objects.get(indx);
        Player p = a.player;
        if ( (a.kill() != -1)  && (p != null ) )
        {
          sendKill(p.prefix, myLocation);
          sendKill(p.prefix, myBroadcastLocation);
        }
        
      }
      else 
      {
        println("beatin' meat!");
      }
}
public void joystickData(int x, int z) 
{
  if (joystick != null)
  {
    if ((z > 110) && (z <= 135)) { joystick.x = 0; }
    else { joystick.x = map(constrain(z, 0, 256), 0, 256, -1, 1); }
    if ((x > 110) && (x <= 135)) { joystick.z = 0;} 
    else { joystick.z = map(constrain(x, -32, 220), -32, 220, -1, 1); }
    
    joystick.x *= 2.5;
    joystick.z *= 2.5;
  }
}

public void accelData(int x, int y, int z) 
{ 
    if (acc != null && ADEBUG == 1)
    {
      println("Receiving accel Data");
      if ((x > -30) && (x <= 30)) { acc.x = 0; } 
      else { acc.x = map(constrain(x, -70, 70), -70, 70, -1, 1); }

      acc.y = map(constrain(y, 30, 120), 30, 120, -1, 1);
      acc.z = acc.y;
      
      acc.x *= -1.5;
      acc.y *= -1.0; //this is a "set" not an "increment.
    }
 }




//-----OSC RECIEVE
void oscEvent(OscMessage theOscMessage) 
{
  //println("###2 received an osc message with addrpattern "+theOscMessage.addrPattern()+" and typetag "+theOscMessage.typetag());
  //theOscMessage.print();
  String messageIP = theOscMessage.netaddress().address();
  String messageaddr = theOscMessage.addrPattern();
  String messagetag = theOscMessage.typetag();
  String iaddr = roster.removePrefix(messageaddr);
  int isin = roster.indexFromAddrPattern(messageaddr); //this could be the only check function, because "begins with" is the same as "equals"
  
  //player initialization message. 
  if (messageaddr.equals("/players/add")) //remember this fucking string functions you fucking cunt don't fuck up and fucking == with two strings.
  {
    connected = true; //ought to be another message that just sets this.
    String iprefix = theOscMessage.get(0).stringValue();
    if (roster.isMe(iprefix)) { return; }
    roster.add(iprefix); //function checks "isin"
    roster.print();
    return;
  }
  
  //player removal message
  if (messageaddr.equals("/players/remove")) //remember this fucking string functions you fucking cunt don't fuck up and fucking == with two strings.
  {
    String iprefix = theOscMessage.get(0).stringValue();
    int rosterindx = roster.indexFromPrefix(iprefix);
    if ( rosterindx == -1 || iprefix.equals(myprefix) ) { return; } //isme/isn't in there.
    else 
    {
      Player iplayer = roster.players.get(rosterindx);
      map.remove(iplayer.avatar); //checks "isin" so null won't throw
      roster.remove(iprefix); //function checks "isin"
    }
    
    //roster.print();
    return;
  }
  
  if (messageaddr.equals("/chuck/init"))
  {
    loop();
    if (randomSpawnCamera(5000) == -1)
    {
      cam.living = false; 
      sendKill(myprefix, myLocation);
      sendKill(myprefix, myBroadcastLocation);
      println("chaos reigns!");
    }
  }
  
  if (messageaddr.equals("/object") && messagetag.equals("ffffffs"))
  {
    float ix = theOscMessage.get(0).floatValue();
    float iy = theOscMessage.get(1).floatValue();
    float iz = theOscMessage.get(2).floatValue();
    float irx = theOscMessage.get(3).floatValue();
    float iry = theOscMessage.get(4).floatValue();
    float irz = theOscMessage.get(5).floatValue();
    String itype = theOscMessage.get(6).stringValue();
    
    if (itype.equals("obelisk")) 
    { 
      PVector ivec = adjustY(new PVector(ix, iy, iz), terrain, iy);
      O3DObelisk iobject = new O3DObelisk(ivec, new PVector(irx, iry, irz), new PVector(random(20, 60), random(160, 250), random(20, 60)));  
      map.add(iobject); 
    }
    else if (itype.equals("cone")) 
    { 
      PVector ivec = adjustY(new PVector(ix, iy, iz), terrain, iy);
      O3DCone iobject = new O3DCone(ivec, new PVector(irx, iry, irz), new PVector(random(20, 90), random(90, 180), random(20, 90))); 
      map.add(iobject); 
    }
    else if (itype.equals("spire")) 
    { 
      PVector ivec = adjustY(new PVector(ix, iy, iz), terrain, iy);
      PVector isize = new PVector(random(40, 90), random(150, 250), random(40, 90)); 
      Spire iobject = new Spire(ivec, new PVector(irx, iry, irz), isize); 
      map.add(iobject); 
    }
    else { println("recieved bad object type"); }
    
  }
  
  if (isin != -1)
  {
    Player iplayer = roster.players.get(isin);
    
    if (iaddr.equals("/shot") && messagetag.equals("ffffff"))
    {
      //println("###2 received an osc message with addrpattern "+the.addrPattern()+" and typetag "+theOscMessage.typetag());
      //the.print();
        float ipx = theOscMessage.get(0).floatValue();
        float ipy = theOscMessage.get(1).floatValue();
        float ipz = theOscMessage.get(2).floatValue();
        float ix = theOscMessage.get(3).floatValue();
        float iy = theOscMessage.get(4).floatValue();
        float iz = theOscMessage.get(5).floatValue();
        
        Avatar a = iplayer.avatar;
        if (a != null) 
        {
          a.startLaser(new PVector(ix, iy, iz));
        }
    }
    
    if (iaddr.equals("/melee") && messagetag.equals("i"))
    {
      //println("###2 received an osc message with addrpattern "+the.addrPattern()+" and typetag "+theOscMessage.typetag());
      //the.print();
        Avatar a = iplayer.avatar;
        if (a != null) 
        {
          a.melee();
        }
    }
    
    //a player has been killed
    if (iaddr.equals("/kill") && messagetag.equals("s"))
    {
      //println("###2 received an osc message with addrpattern "+theOscMessage.addrPattern()+" and typetag "+theOscMessage.typetag());
      //theOscMessage.print();
      String is = theOscMessage.get(0).stringValue();
      if (is.equals(myprefix)) 
      {
        sendKill(myprefix, myLocation);
        cam.living = false;
      }
      else //everything below should be encapsulated.
      {
        sendKill(is, myLocation);
        int indx = roster.indexFromPrefix(is);
        if (indx != -1)
        {
          Player player = roster.players.get(indx);
          Avatar avatar = player.avatar;
          if (avatar != null);
          {
            avatar.kill();
          }
        }
        
      }
    }
  

    
    //player positions, currently updated at draw-rate (could be just at change))
    else if (iaddr.equals("/pos") && messagetag.equals("ffffff"))
    {
        float ix = theOscMessage.get(0).floatValue();
        float iy = theOscMessage.get(1).floatValue();
        float iz = theOscMessage.get(2).floatValue();
        float irx = theOscMessage.get(3).floatValue();
        float iry = theOscMessage.get(4).floatValue();
        float irz = theOscMessage.get(5).floatValue();
        
        PVector ip = new PVector(ix, iy, iz); //ignore lookheight
        PVector ir = new PVector(irx, iry, irz); //don't rotate avatar
        
        //println("before indexOF!");
        if (map.objects.indexOf(iplayer.avatar) == -1) //if player does not have an avatar in the map.
        {
          //println("after indexOF! true!");
          
          PVector ivec = adjustY(new PVector(ix, iy, iz), terrain, height_OFFSET);
          PVector isize = new PVector(random(20, 90), random(90, 180), random(20, 90));  
          Avatar ia = new Avatar(iplayer, ivec, new PVector(0, 0, 0), isize);
          iplayer.avatar = (map.add(ia) != -1) ? ia : null; 
          //if avatar is successfully added to the map, else set player's avatar pointer to null.
          //println("model:", iplayer.avatar.getModelApex());
        }
        else
        {
          //println("after indexOF! false!");
          PVector ivec = adjustY(new PVector(ix, iy, iz), terrain, height_OFFSET);
          map.move(iplayer.avatar, ivec, new PVector(0, 0, 0));
           //println("model:", iplayer.avatar.getModelApex());
        }

    }
}
}


void keyPressed()
{
  switch(key)
  {
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
    case 'c': 
    {
      sendMelee(1, myLocation);
      sendMelee(1, myBroadcastLocation);
      int indx = map.checkBounds(cam.pos, STRIKE_RADIUS);
      if (map.isAvatar(indx))
      {
        Avatar a = (Avatar) map.objects.get(indx);
        Player p = a.player;
        if ( (a.kill() != -1)  && (p != null ) )
        {
          sendKill(p.prefix, myLocation);
          sendKill(p.prefix, myBroadcastLocation);
        }
        
      }
      else 
      {
        println("beatin' meat!");
      }
      break;
    }
    case 'z':
    {
      cam.laser = 1.0;
      sendShot(cam.pos, cam.aim, myLocation);
      sendShot(cam.pos, cam.aim, myBroadcastLocation);
      int indx = map.getIndexByAngle(cam.pos, cam.aim);
      if (map.isAvatar(indx)) //checks for -1
      {
        Avatar a = (Avatar) map.objects.get(indx);
        Player p = a.player;
        if ( (a.kill() != -1)  && (p != null ) )
        {
          sendKill(p.prefix, myLocation);
          sendKill(p.prefix, myBroadcastLocation);
        }
        
      }
      else 
        {
          println("shootin' blanks!");
        }
      break;
    }
  }
}

int randomSpawnCamera(int tries) 
{
  for (int i = 0; i <= tries; i++)
  {
    PVector pvec = new PVector(random( -(map.xsize / 2), (map.xsize / 2) ), 0, random( -(map.zsize / 2), (map.zsize / 2) ));
    pvec = adjustY(pvec, terrain, 0);
    PVector rvec = new PVector(0, 0, 0);
    if (map.checkBounds(pvec) == -1)
    {
      //println("pvec", pvec);
      cam.spawnCamera(pvec.get(), rvec);
      return 0;
    }
  }
  return -1;
}

void killCamera()
{
  camera();
  killScreen = loadImage(respawnTex[(int)random(0, respawnTex.length -1)]);
  image(killScreen, 0, 0, width, height);
  sendExplosion();
}

PVector adjustY(PVector ipv, Terrain it)
{
  PVector opv = ipv.get();
  it.adjustPosition(opv, Terrain.WRAP);
 float oy = it.getHeight(opv.x, opv.z);
  opv.y = oy;
  return opv;
}

PVector adjustY(PVector ipv, Terrain it, float ihover)
{
  PVector opv = ipv.get();
  it.adjustPosition(opv, Terrain.WRAP);
  float oy = it.getHeight(opv.x, opv.z) + ihover; //keep in mind this is gonna want a negative value.
  opv.y = oy;
  return opv;
}

void initTextures() //probably not this.
{//for syncing texture changes
  //texGlobe = loadImage(skyTex[texCycle]);   
  texCycle = (texCycle + 1) % 2; 
  laserTexCur = loadImage( laserTex[texCycle] );
  terrainTexCur = loadImage( terrainTex[texCycle] );
  terrain.setTexture(terrainTexCur, TERRAIN_SLICES);
  terrain.drawMode(S3D.TEXTURE);
  println("Texture for laser:", laserTexCur, "Texture for sky:", skyTexCur, "texture for terrain:", terrainTexCur);

  
}

PVector [] shiftGlobalColors()
{
  PVector [] ovec = new PVector[3]; //later, increment these, rather than randomizing.
  ovec[0] = new PVector(random(0, 1), 0, random(0, 1));
  ovec[1] = new PVector(random(0, 1), 0, random(0, 1));
  ovec[2] = new PVector(sin(millis() * .001), 0, cos(millis() * .001));
  return ovec;
}
/*
void initTextures()
{
  laserTexCur = loadImage( laserTex[ (int) random(0, laserTex.length) ] );
  skyTexCur = loadImage( laserTex[ (int) random(0, laserTex.length) ] );
  terrainTexCur = loadImage( laserTex[ (int) random(0, laserTex.length) ] );
  initializeSphere(sDetail);
  //println("Texture for laser:", laserTexCur, "Texture for sky:", skyTexCur, "texture for terrain:", terrainTexCur);
}
*/

