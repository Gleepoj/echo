# echos
[![TravisCI Build Status](https://travis-ci.org/deepcake/echo.svg?branch=master)](https://travis-ci.org/deepcake/echo)

Super lightweight Entity Component System framework for Haxe. 
Initially created to learn the power of macros. 
Focused to be simple and fast. 
Inspired by other haxe ECS frameworks, especially [EDGE](https://github.com/fponticelli/edge), [ECX](https://github.com/eliasku/ecx), [ESKIMO](https://github.com/PDeveloper/eskimo) and [Ash-Haxe](https://github.com/nadako/Ash-Haxe)

#### Wip

#### Overview
 * Component is an instance of `T:Any` class. For each class `T` will be generated a global component container, where instance of `T` is a value and `Entity` is a key. 
 * `Entity` in that case is just an abstract over the `Int`, but with the ability to work with it as with a set of components like in other regular ECS frameworks. 
 * `View<T>` is a collection of entities containing all of the required components of the requested types. 
 * `System` is a place to process data collected by views. 

#### Example
```haxe
import echos.Workflow;
import echos.Entity;
import echos.View;

class Example {

  static function main() {
    Workflow.addSystem(new Movement());
    Workflow.addSystem(new Render());

    for (i in 0...100) createTree(Std.random(500), Std.random(500));

    var rabbit = createRabbit(100, 100, 1, 1);

    trace(rabbit.exists(Position)); // true
    trace(rabbit.get(Position).x); // 100
    rabbit.remove(Position); // oh no!
    rabbit.add(new Position(1, 1)); // okay

    // also somewhere should be Workflow.update(deltatime) call on every tick
  }

  static function createTree(x:Float, y:Float) {
    return new Entity()
      .add(new Position(x, y))
      .add(new Sprite('assets/tree.png'));
  }
  static function createRabbit(x:Float, y:Float, vx:Float, vy:Float) {
    var pos = new Position(x, y);
    var vel = new Velocity(vx, vy);
    var spr = new Sprite('assets/rabbit.png');
    return new Entity().add(pos, vel, spr);
  }
}

// some visual component, openfl.dispaly.Sprite for example
class Sprite { } 
// some 2d vector component
class Vec2 { } 
// abstracts can be used to create different component classes from the same base class without overhead
@:forward abstract Velocity(Vec2) { 
  inline public function new(x, y) this = new Vec2(x, y);
}
@:forward abstract Position(Vec2) {
  inline public function new(x, y) this = new Vec2(x, y);
}

class Movement extends echos.System {
  // @update-functions will be called for each entity that contains all defined components;
  // all args become components, except Float (reserved for delta time) and Int/Entity;
  @update function updateBody(pos:Position, vel:Velocity, dt:Float, entity:Entity) {
    pos.x += vel.x * dt;
    pos.y += vel.y * dt;
  }

  // all required views will be defined and initialized under the hood,
  // but it is also possible to define a View manually (initialization is still not needed) 
  // for additional possibilities like counting entities;
  var bodies:View<Position->Velocity->Void>;

  // @update-function without components will be called just once per system update;
  @update function printBodies(dt:Float) {
    trace(bodies.entities.length); // only one rabbit
    // another way to iterating over entities
    bodies.iter((entity, position, velocity) -> trace('#$entity vel = $velocity'));
  }
}

class Render extends echos.System {
  var scene:Array<Sprite> = [];

  // @a, @u and @r are the shortcuts for @added, @update and @removed;

  // execution order of the @update-functions is the same to the definition order, 
  // so it is possible to do some preparations before or after iterating over entities;
  @u inline function beforeSpritePositionsUpdated() {
    trace('start updating sprite positions!');
  }
  @u inline function updateSpritePosition(spr:Sprite, pos:Position) {
    spr.x = pos.x;
    spr.y = pos.y;
  }
  @u inline function afterSpritePositionsUpdated() {
    scene.sort(function(s1, s2) return s2.y - s1.y); // sort by y-axis for 2d, for example
    // rendering ...
  }

  // @added/@removed-functions are the callbacks called when entity is added or removed from the view;
  @a function onEntityWithSpriteAnpPositionAdded(spr:Sprite, pos:Position) {
    scene.push(spr);
  }
  // even if callback was triggered by destroying the entity or removing a required component, 
  // @removed-function will be called before that will actually happened, 
  // so access to the component will be still exists;
  @r function onEntityWithSpriteAnpPositionRemoved(spr:Sprite, pos:Position, entity:Entity) {
    scene.remove(spr);
    trace('Oh My God! They removed $entity!');
  }
}
```


[Live Example](https://deepcake.github.io/echo/web/) - Tiger in the Meatdow! ([source](https://github.com/deepcake/echo/blob/master/example/TigerInTheMeatdow.hx))


#### Also
There is also exists a few additional compiler flags:
 * `-D echos_profiling` - collecting some more info in `Workflow.toString()` method for debug purposes
 * `-D echos_report` - traces a short report of built components and views
 * `-D echos_array_cc` - using Array<T> instead IntMap<T> for global component containers (wip)

#### Install
```haxelib git echos https://github.com/deepcake/echo.git```
