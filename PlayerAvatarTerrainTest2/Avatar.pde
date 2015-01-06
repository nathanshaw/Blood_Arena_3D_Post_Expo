class Avatar extends O3DCone
{
  Player player;
  //boolean isLiving;
  Laser laser;
  //could have a "shader" parameter that is set along with death and melee. then, we don't have to call so much if/then in display
  //PShader shader;
  float lifespan;
  float melee;
  
  float D_THRESH = .1;
  float D_RATE = .98;
  float M_THRESH = .001;
  float M_RATE = .98;
  float L_THRESH;
  float L_RATE;
  
  Avatar(Player iplayer, PVector ip, PVector ir, PVector isize)
  {
    super(ip, ir, isize);
    type = "avatar";
    player = iplayer;
    laser = new Laser(1.0, 1.0, 1.0, 1.0, new PVector(p.x, p.y-isize.y, p.z)); //set it to apex, later.
    //shader = SHADER_NOISE;
    println("new Avatar!", p, r, player.prefix);
    isLiving = 1;
    
    lifespan = 0.0;
    melee = 0.0;
  }
  
  void update()
  { 
    if (isLiving == 1)
    {
      if (melee > M_THRESH)
      {
        melee *= M_RATE;
        println("melee!");
      }
      else 
      {
        melee = 0.0;
      }
    }
    else if (isLiving == 0)
    {
      if (lifespan > D_THRESH) 
      { 
        lifespan *= D_RATE;
      }
      else
      {
        lifespan = 0.0;
        isLiving = -1;
      }
    }
  }

  void display()
  {
    if (isLiving == 1) //rather than these checks, could implement a dig where the shader is set externally, and handle most stuff in-shader with millis()
    {
      if (melee > M_THRESH) 
      { 
        SHADER_MELEE.set("time", (millis() % 10000) * .001); //elapsed could be set to the initial elapsed value, then mod by that number to get count from 0
        SHADER_MELEE.set("resolution", (float) width, (float) height);
        SHADER_MELEE.set("pixels", melee * 1000.0);
        shader(SHADER_MELEE); 
      }
      super.display();
      resetShader();
      SHADER_LASER.set("time", (millis()) * .001); //elapsed could be set to the initial elapsed value, then mod by that number to get count from 0
      SHADER_LASER.set("resolution", (float) width, (float) height);
      SHADER_LASER.set("alpha", 1.0);
      
      SHADER_LASER.set("bars1", lerp(800.0, 500.0, (1.0 - laser.lifespan)));
      SHADER_LASER.set("bars2", 500.0);
      
      SHADER_LASER.set("thresh1", 0.2);
      SHADER_LASER.set("thresh2", 0.8 * lifespan);
      
      SHADER_LASER.set("rate1", 20.0);
      SHADER_LASER.set("rate2", 12.0);
      SHADER_LASER.set("color", .8, 0.0, .6);
      shader(SHADER_LASER);
      laser.update(); //right now, this's all that'd be in "update" for any object excepting the camera.
      laser.display();
      resetShader();
    }
    else if (isLiving == 0)
    {
      
      SHADER_DEATH.set("time", millis() * .001);
      SHADER_DEATH.set("resolution", (float) width, (float) height);
      SHADER_DEATH.set("floor", lerp(.8, 2.0, pow((1 - lifespan), 2))); //lerp(.8, 1.0, (1 - lifespan)));
      SHADER_DEATH.set("ceil", .8);
      SHADER_DEATH.set("alpha", .8);
    
      SHADER_DEATH.set("mouse", (float) width/2, (float) (-acc.y * height/2) + height/2);
    
      SHADER_DEATH.set("circle_radius", lerp(.08, 1.0, (1-lifespan))); //relative to center of screen.
      SHADER_DEATH.set("border", 1.0); //1.0 for filled circle
      SHADER_DEATH.set("periods", 50.0); //high or 1-2
      SHADER_DEATH.set("rate", 50.0);
      
      SHADER_DEATH.set("mix", 1 - lifespan);
      SHADER_DEATH.set("cover", 0.6); //amount of clouds v/ black 
      SHADER_DEATH.set("sharpness", 0.0003); //at zero this is just white and black
      
      SHADER_DEATH.set("color", 1.0, 0.0, 0.0); //new PVector(random(1.0), 0.0, random(1.0)));

      shader(SHADER_DEATH);
      super.display();
      resetShader();
    }
  }
  
  void startLaser(PVector ipos, PVector iaim)
  {
    laser.set(ipos, iaim, .88, .08);//laser.adjustToTerrain?
  }
  
  void startLaser(PVector iaim)
  {
    laser.set(new PVector(p.x, p.y-size.y, p.z), iaim, .88, .08); //laser.adjustToTerrain?
  }
  
  void melee()
  {
    melee = 1.0;
  }
  
  int kill()
  {
    if (isLiving == 1)
    {
      isLiving = 0;
      lifespan = 1.0;
      if (player != null)
      {
        player.avatar = null;
        player = null;
      }
      return 0;
    }
    return -1;
  }
  
  void print()
  {
    println("Avatar for player "+player.prefix+"", "position:", p, "rotation", r);
  }
}
