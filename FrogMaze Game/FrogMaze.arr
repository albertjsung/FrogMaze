use context essentials2021
#|             
██████╗██████╗  ██████╗  ██████╗    ██████╗  █████╗  ██████╗███████╗
██╔═══╝██╔══██╗██╔═══██╗██╔════╝    ██╔══██╗██╔══██╗██╔════╝██╔════╝
██████╗██████╔╝██║   ██║██║ ████╗   ██████╔╝███████║██║     █████╗    
██╔═══╝██╔══██╗██║   ██║██║ ╚═██║   ██╔══██╗██╔══██║██║     ██╔══╝ 
██║    ██║  ██║╚██████╔╝╚██████╔╝   ██║  ██║██║  ██║╚██████╗███████╗ 
╚═╝    ╚═╝  ╚═╝ ╚═════╝  ╚═════╝    ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝
|#

include shared-gdrive("dcic-2021", "1wyQZj_L0qqV9Ekgr9au6RX2iqt2Ga8Ep")
include shared-gdrive("project2-support-fall24.arr", "1BBNcHnYHMF72ZxNHsfZU7E6uLpsdZEla")
include reactors

#######################################################################
# -------------------- External Data & Constants ---------------------#
#######################################################################

ssid = "1oVYyaOr9G8siVgEThoB6h9tgD8L1KOs4w7T3dsLs72A"
 
# load maze from spreadsheet into List<List<String>>
maze-grid  = load-maze(ssid) 
   
# load item positions from spreadsheet into Table form
item-table = load-items(ssid) 

# Loads all images for the game: You will need to use these constants!
base-url = "https://code.pyret.org/shared-image-contents?sharedImageId="
princess-img = image-url(base-url + "1JzZiAQE_PwONvsTovKHdPUmi-bOxhmFW")
duck-img = image-url(base-url + "1ifOvq7qj9yuN6bQjjYx5Xlg4W6vPZEc2")
worm-img = image-url(base-url + "1JswaZtbKofY68E7rAB3EALw7BqFuVIVO")
lilypad-img = image-url(base-url + "1TqLCh-2m8yqOPsB10vGP8at5t2z-f3Lp")
frog-img = image-url(base-url + "1VrM7CyDF5A4fojiHiA9Sf9E81kd_Ij6S")
water-img = image-url(base-url + "19fqjNeJlavkuUCtuBN26lwKzRpWBPzZI")
insect-img = image-url(base-url + "1yRkfimHfOd3f0bEkYttJ_46AqAwIBM3a")
grass-img = image-url(base-url + "1d4eOV1CXQ4I5suYmuAnZcUu3Vy4FnGvN")

"--------------------------------------------------------------------------------------------------"
MAX-STAMINA = 30 # default max stamina value

DUCK-VALUE = 10 # stamina value after encountering a duck

INSECT-VALUE = MAX-STAMINA # stamina value after eating an insect

WORM-VALUE = 7 #stamina gained by the frog after hitting a worm

MV-COST = 1 #the movement cost of 1 stamina per cell. (1 / 30 stam per pixel)

"--------------------------------------------------------------------------------------------------"
data Coord:
  | coord(x :: Number, y :: Number)
end

data Cell:
  | grass
  | water
end

data Player:
  |frog(c :: Coord, st :: Number)  
end

data Widget:
  |worm(c :: Coord)
  |insect(c :: Coord) #brings player to full st
  |duck(c :: Coord) #brings player to low st
  |princess(c :: Coord)
end

data GameState:     
  |game(
      frog :: Player,
      widget-list :: List<Widget>,
      is-ended :: Boolean)
end
"--------------------------------------------------------------------------------------------------"
fun convert-to-pixels(n :: Number) -> Number:
  doc: ```takes in a grid xy coordinates and converts it into pixels, based on the second input. 
       Intended for eventual pyret xy coordinate conversion``` 
 n * 30
where:
  convert-to-pixels(2) is 60
  convert-to-pixels(0) is 0
end

MAZE-LENGTH = convert-to-pixels(length(maze-grid.get(0)))
MAZE-WIDTH = convert-to-pixels(length(maze-grid))

fun tile-conversion(xy-component :: Number) -> Number:
  doc: 'given xy coordinate of player or object, outputs x or y component of the tile coordinates'
  if (num-modulo(xy-component, 30)) == 0:
    xy-component / 30 
  else:
    num-truncate(xy-component / 30) + 1
  end
where:
  tile-conversion(45) is 2
  tile-conversion(1) is 1
end

fun convert-to-tile-coordinates(coord-xy :: Coord) -> Coord:
  doc: 'given xy coordinate of the player or object in the Widget List, produces tile coordinates'
  coord(tile-conversion(coord-xy.x), tile-conversion(coord-xy.y))
where:
  convert-to-tile-coordinates(coord(45, 45)) is coord(2, 2)
  convert-to-tile-coordinates(coord(1, 1)) is coord(1, 1)
end
"--------------------------------------------------------------------------------------------------"
fun Cells(maze-list :: List<List>) -> List<Cell>:
  doc: 'converts the maze-list into a list of Cells for reader clarity and for future functions'
  map(lam(l):
      map(lam(s):
          if s == 'o':
            water
          else:
            grass
          end
          end,
          l)
      end,
      maze-list
      )
where:
  Cells([list: [list: 'x', 'o']]) is [list: [list: grass, water]]
end

Cells(maze-grid) #list containing information on cell type for each row of the Maze
"--------------------------------------------------------------------------------------------------"
fun convert-to-grass(maze-list :: List<Cell>) -> List<List>:
  doc: ```converts a list of lists of Cells, representing a grid, to a list of lists of grass 
       and water image```  
  map(lam(l):
      map(lam(s): 
          if s == water:
            water-img
          else:
            grass-img
          end
        end,
        l)
    end,
    maze-list
    )
where:
  convert-to-grass([list: [list: grass, water]]) is [list: [list: grass-img, water-img]]
  convert-to-grass([list: [list: water, water]]) is [list: [list: water-img, water-img]]
end

fun horiz-combine(img-list :: List<Image>) -> Image:
  doc: "combines the tiles horizontally using Pyret's provided beside function"
  cases(List) img-list:
    |empty => empty-image
    |link(f,r) => 
      beside(f, horiz-combine(r))     
  end
end

fun vert-combine(img-list :: List<Image>) -> Image:
  doc: "combines tiles vertically using Pyret's provided above function"
  cases(List) img-list:
    |empty => empty-image
    |link(f,r) => 
      above(f, vert-combine(r))
  end
end

tiles = convert-to-grass(Cells(maze-grid))

#full, static maze background we'll be using to draw objects on
BACKGROUND = vert-combine( 
  map({(r :: List<Image>) -> Image: horiz-combine(r)}, tiles)) 

rectangle-width = MAZE-WIDTH
rectangle-length = MAZE-LENGTH / 25

fun stamina-bar(gameState :: GameState) -> Image:
  doc: "takes in the game state to draw the appropriate stamina bar of the Player (frog)"
  grey-rectangle = rectangle(rectangle-length, rectangle-width, 'solid', 'grey')
  overlay-align('center', 'bottom', 
    rectangle(rectangle-length, 19 * gameState.frog.st, 'solid', 'gold'), grey-rectangle)
end
"--------------------------------------------------------------------------------------------------"
widget-table-pixels = item-table.transform-column("x", 
  {(x :: Number) -> Number: convert-to-pixels(x) + 15}).transform-column("y", 
  {(y :: Number) -> Number: convert-to-pixels(y) + 15})

widget-table = widget-table-pixels.build-column("Widgets", lam(r): 
    if r["name"] == "Insect":
      insect(
        coord(r["x"], r["y"])
        )
    else if r["name"] == "Worm":
      worm(
        coord(r["x"], r["y"])
        )
    else if r["name"] == "Princess":
      princess(
        coord(r["x"], r["y"])
        )
    else:
      duck(
        coord(r["x"], r["y"])
        )
    end
  end)

#our global widget-list used for the initial-game-state
initial-widget-list = widget-table.get-column("Widgets") 

initial-game-state = game(
  frog(coord(45, 45), MAX-STAMINA),
  initial-widget-list,
  false)
"--------------------------------------------------------------------------------------------------"
fun draw-rest(l :: List<Widget>, gameState :: GameState) -> Image:
  doc: ```takes in the gamestate and widget list and produces an image of the background with the 
  Widgets placed in their respective coordinate positions```
  cases (List) l:
    | empty => place-image(frog-img, gameState.frog.c.x, gameState.frog.c.y, BACKGROUND)
    | link(f,r) => 
      x = f.c.x 
      y = f.c.y
      if is-worm(f):
        place-image(worm-img, x, y, draw-rest(r, gameState))
      else if is-insect(f):
        place-image(insect-img, x, y, draw-rest(r, gameState))
      else if is-princess(f):
        place-image(princess-img, x, y, draw-rest(r, gameState))
      else:
        place-image(duck-img, x, y, draw-rest(r, gameState))
      end
  end
end

fun draw-gameboard(gameState :: GameState) -> Image:
  doc: "takes in a GameState and draws its gameboard at the given xy tile coords for the object"
  beside(draw-rest(gameState.widget-list, gameState), stamina-bar(gameState))
end
"--------------------------------------------------------------------------------------------------"
fun worm-interaction(gameState :: GameState) -> Number:
  doc: 'when frog eats worm and exceeds MAX-STAMINA, caps stam at MAX-STAMINA'
  if (gameState.frog.st + WORM-VALUE) > MAX-STAMINA:
    MAX-STAMINA
  else:
    gameState.frog.st + WORM-VALUE
  end
where:
  worm-interaction(game(frog(coord(75, 45), 25), initial-widget-list, false)) is 30 
  #tests if the function effectively caps stamina at 30, since 25 + 7 > 30
  worm-interaction(game(frog(coord(75, 45), 20), initial-widget-list, false)) is 27
  #tests if the function properly adds worm-value otherwise
end

fun duck-interaction(gameState :: GameState) -> Boolean:
  doc: 'function for when the frog eats the duck and its stam is below DUCK-VALUE, ends the game'
  if (gameState.frog.st < DUCK-VALUE):
    true
  else:
    false
  end
where:
  duck-interaction(game(frog(coord(75, 45), 9), initial-widget-list, false)) is true
  duck-interaction(game(frog(coord(75, 45), 11), initial-widget-list, false)) is false
end
"--------------------------------------------------------------------------------------------------"
fun find-grass(place :: List<List>, tile-coordinates :: Coord) -> Boolean:
  doc: ```takes in the maze-grid and the frog's coordinates and returns a boolean determining 
       whether or not the frog is in a grass tile```
  current-tile = place.get(tile-coordinates.y - 1).get(tile-coordinates.x - 1)
  if current-tile == grass:
    true
  else:
    false
  end
where: 
  find-grass(Cells(maze-grid), coord(1, 1)) is true
  find-grass(Cells(maze-grid), coord(2, 2)) is false
end
"--------------------------------------------------------------------------------------------------"
fun detect-collision(gameState :: GameState, widgets :: List<Widget>) -> GameState:
  doc: 'helper function for on-key-press that checks collision every time the GameState is updated'
  cases (List) widgets:
    |empty => gameState
    |link(f,r) =>
      updated-widget-list = gameState.widget-list.filter({(w :: Widget) -> Boolean: w <> f})

      if gameState.frog.c == f.c:
        if is-worm(f):
          game(frog(coord(gameState.frog.c.x, gameState.frog.c.y), worm-interaction(gameState)),
            updated-widget-list, 
            gameState.is-ended)
        else if is-insect(f):
          game(frog(coord(gameState.frog.c.x, gameState.frog.c.y), MAX-STAMINA),
            updated-widget-list, 
            gameState.is-ended)
        else if is-princess(f):
          game(frog(coord(gameState.frog.c.x, gameState.frog.c.y), gameState.frog.st),
            updated-widget-list, 
            true)
        else: 
          game(frog(coord(gameState.frog.c.x, gameState.frog.c.y), DUCK-VALUE),
            updated-widget-list, 
            duck-interaction(gameState))
        end
      else:
        detect-collision(gameState, r)
      end
  end
where:
  #no expected collision here, since this is our starting screen.
  detect-collision(initial-game-state, initial-widget-list) is initial-game-state 
  
  #tests the first collision interaction of the game, where the frog collides with the duck
  detect-collision(game(frog(coord(105, 45), MAX-STAMINA), initial-widget-list, false), 
    initial-widget-list) is game(frog(coord(105, 45), DUCK-VALUE), 
    initial-widget-list.filter({(w :: Widget) -> Boolean: not(is-duck(w))}), false)
end
"--------------------------------------------------------------------------------------------------"
sample-gameState = game(frog(coord(45, 75), 29), initial-widget-list, false)
no-collision-state = game(frog(coord(75, 45), 29), initial-widget-list, false)

fun wall-collision(gameState :: GameState, new-gameState :: GameState) -> GameState:
  doc: ```Determines if a wall collision will occur by taking in the new-gamestate, which is the 
       gamestate once key press (wasd) occurs, and if there is a collision, returns the original 
       gamestate to prevent the Player (frog) from going out of bounds```
  
  if find-grass(Cells(maze-grid), convert-to-tile-coordinates(new-gameState.frog.c)):
    gameState
  else:
    new-gameState
  end
  
where:
  wall-collision(initial-game-state, sample-gameState) is initial-game-state
  wall-collision(initial-game-state, no-collision-state) is no-collision-state
end

fun updated-coordinates(gameState :: GameState, key-input :: String) -> Coord:
  doc: 'given a specific key input, updates coordinates based on input'
  
  increment = 30 #movement unit, in pixels (effectively moves frog one tile)
  
  if key-input == 'w':
    coord(gameState.frog.c.x, gameState.frog.c.y - increment)

  else if key-input == 'a':
    coord(gameState.frog.c.x - increment, gameState.frog.c.y)

  else if key-input == 's':
    coord(gameState.frog.c.x, gameState.frog.c.y + increment)

  else if key-input == 'd':
    coord(gameState.frog.c.x + increment, gameState.frog.c.y)
    
  else:
    coord(gameState.frog.c.x, gameState.frog.c.y)
  end
  
where:
  updated-coordinates(initial-game-state, 's') is coord(45, 75)
  updated-coordinates(initial-game-state, 'd') is coord(75, 45)
end

fun on-key-press(gameState :: GameState, key :: String) -> GameState:
  doc: ```function that takes in a key (one of WASD) and a game state and returns a modified
 GameState corresponding to the movement. uses detect-collision and wall-collisions as helpers to constantly update the GameState when collisions occur.``` 
  increment = 30
  stam-increment = gameState.frog.st - (increment * (1 / 30))
  
  if [list: 'w','a','s','d'].member(key) == true:
    updated-gameState = game(frog(
      updated-coordinates(gameState, key),
      stam-increment), 
    gameState.widget-list, gameState.is-ended)
    
    detect-collision(wall-collision(gameState, updated-gameState), gameState.widget-list)
   
  else:
    gameState
  end
  
where:
  on-key-press(initial-game-state, 's').frog.c is coord(45, 45) #frog is now bounded by the maze
  on-key-press(initial-game-state, 'd').frog.c is coord(75, 45) #valid movement for the frog
end
"--------------------------------------------------------------------------------------------------"
game-over-state = game(frog(coord(75, 45), 0), initial-widget-list, false)

fun game-end(gameState :: GameState) -> Boolean:
  doc: ```function that indicates when the game is over: if the frog stamina hits 0 or the frog hits 
       the princess, the function returns true, indicating the end of the game```
  if gameState.frog.st <= 0:
    true
  else if gameState.is-ended == true:
    true
  else:
    false
  end
where:
  game-end(game-over-state) is true
  game-end(initial-game-state) is false
end
"--------------------------------------------------------------------------------------------------"
final-reactor = reactor:
  init: initial-game-state,
  to-draw: draw-gameboard,
  on-key: on-key-press,
  stop-when: game-end
end

#execute the game, opening the interactive window
interact(final-reactor)