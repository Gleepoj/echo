package echoes;

import echoes.Entity.Status;
import echoes.core.AbstractView;
import echoes.core.ICleanableComponentContainer;
import echoes.core.ISystem;
import echoes.core.RestrictedLinkedList;

/**
 *  Workflow  
 * 
 * Systems live in one of two lists, named after the deepnight game loop hooks that update them:
 * - **fixed** systems, updated by `fixedUpdate(dt)`: called a fixed number of times per second (simulation, physics, rules),
 * - **post** systems, updated by `postUpdate(dt)`: called once per rendered frame, variable dt (display, camera, UI, input).
 * A system belongs to one list only.
 * 
 * @author https://github.com/deepcake
 */
class Workflow {


    @:allow(echoes.Entity) static inline var INVALID_ID = -1;


    static var nextId = INVALID_ID + 1;

    static var idPool = new Array<Int>();

    static var statuses = new Array<Status>();

    // all of every defined component container
    static var definedContainers = new Array<ICleanableComponentContainer>();
    // all of every defined view
    static var definedViews = new Array<AbstractView>();

    /**
     * All active entities
     */
    public static var entities(default, null) = new RestrictedLinkedList<Entity>();
    /**
     * All active views
     */
    public static var views(default, null) = new RestrictedLinkedList<AbstractView>();

    /**
     * Systems updated by `fixedUpdate()`
     */
    public static var fixedSystems(default, null) = new RestrictedLinkedList<ISystem>();
    /**
     * Systems updated by `postUpdate()`
     */
    public static var postSystems(default, null) = new RestrictedLinkedList<ISystem>();


    #if echoes_profiling
    static var fixedUpdateTime = .0;
    static var postUpdateTime = .0;
    #end


    /**
     * Returns the workflow statistics:  
     * _( systems count ) { views count } [ entities count | entity cache size ]_  
     * With `echoes_profiling` flag additionaly returns:  
     * _( system name ) : time for update ms_  
     * _{ view name } [ collected entities count ]_  
     * @return String
     */
    public static function info():String {
        var ret = '# ( ${fixedSystems.length + postSystems.length} ) { ${views.length} } [ ${entities.length} | ${idPool.length} ]'; // TODO version or something

        #if echoes_profiling
        ret += ' : ${fixedUpdateTime + postUpdateTime} ms'; // total
        for (s in fixedSystems) {
            ret += '\n${ s.info('    ', 1) }';
        }
        if (postSystems.length > 0) {
            ret += '\n    postUpdate : $postUpdateTime ms';
            for (s in postSystems) {
                ret += '\n${ s.info('    ', 2) }';
            }
        }
        for (v in views) {
            ret += '\n    {$v} [${ v.entities.length }]';
        }
        #end

        return ret;
    }


    /**
     * Updates the fixed systems (see `fixedSystems`)
     * @param dt deltatime of one fixed step
     */
    public static function fixedUpdate(dt:Float) {
        #if echoes_profiling
        var timestamp = Date.now().getTime();
        #end

        for (s in fixedSystems) {
            s.__update__(dt);
        }

        #if echoes_profiling
        fixedUpdateTime = Std.int(Date.now().getTime() - timestamp);
        #end
    }

    /**
     * Updates the post systems (see `postSystems`)
     * @param dt deltatime of the frame
     */
    public static function postUpdate(dt:Float) {
        #if echoes_profiling
        var timestamp = Date.now().getTime();
        #end

        for (s in postSystems) {
            s.__update__(dt);
        }

        #if echoes_profiling
        postUpdateTime = Std.int(Date.now().getTime() - timestamp);
        #end
    }

    /**
     * Removes all views, systems and entities from the workflow, and resets the id sequence 
     */
    public static function reset() {
        for (e in entities) {
            e.destroy();
        }
        for (s in fixedSystems) {
            removeSystem(s);
        }
        for (s in postSystems) {
            removeSystem(s);
        }
        for (v in definedViews) {
            v.reset();
        }
        for (c in definedContainers) {
            c.reset();
        }

        idPool.splice(0, idPool.length);
        statuses.splice(0, statuses.length);

        nextId = INVALID_ID + 1;
    }


    // System

    /**
     * Adds the system to the workflow, updated by `fixedUpdate()`. Ignored if it is already added (to any list)
     * @param s `System` instance
     */
    public static function addFixedSystem(s:ISystem) {
        if (!hasSystem(s)) {
            fixedSystems.add(s);
            s.__activate__();
        }
    }

    /**
     * Adds the system to the workflow, updated by `postUpdate()`. Ignored if it is already added (to any list)
     * @param s `System` instance
     */
    public static function addPostSystem(s:ISystem) {
        if (!hasSystem(s)) {
            postSystems.add(s);
            s.__activate__();
        }
    }

    /**
     * Removes the system from the workflow, whichever list it is in
     * @param s `System` instance
     */
    public static function removeSystem(s:ISystem) {
        if (fixedSystems.exists(s)) {
            s.__deactivate__();
            fixedSystems.remove(s);
        }
        else if (postSystems.exists(s)) {
            s.__deactivate__();
            postSystems.remove(s);
        }
    }

    /**
     * Returns `true` if the system is added to the workflow (to any list)
     * @param s `System` instance
     * @return `Bool`
     */
    public static function hasSystem(s:ISystem):Bool {
        return hasFixedSystem(s) || hasPostSystem(s);
    }

    public static inline function hasFixedSystem(s:ISystem):Bool {
        return fixedSystems.exists(s);
    }

    public static inline function hasPostSystem(s:ISystem):Bool {
        return postSystems.exists(s);
    }



    // Entity

    @:allow(echoes.Entity) static function id(immediate:Bool):Int {
        var id = idPool.pop();

        if (id == null) {
            id = nextId++;
        }

        if (immediate) {
            statuses[id] = Active;
            entities.add(id);
        } else {
            statuses[id] = Inactive;
        }
        return id;
    }

    @:allow(echoes.Entity) static function cache(id:Int) {
        // Active or Inactive
        if (status(id) < Cached) {
            removeAllComponentsOf(id);
            entities.remove(id);
            idPool.push(id);
            statuses[id] = Cached;
        }
    }

    @:allow(echoes.Entity) static function add(id:Int) {
        if (status(id) == Inactive) {
            statuses[id] = Active;
            entities.add(id);
            for (v in views) v.addIfMatched(id);
        }
    }

    @:allow(echoes.Entity) static function remove(id:Int) {
        if (status(id) == Active) {
            for (v in views) v.removeIfExists(id);
            entities.remove(id);
            statuses[id] = Inactive;
        }
    }

    @:allow(echoes.Entity) static inline function status(id:Int):Status {
        // Out of range = Entity.INVALID, or an entity created before the last `reset()`.
        // (Reading past the array returns 0 = Inactive on some targets, making stale entities look valid.)
        return id < 0 || id >= statuses.length ? Invalid : statuses[id];
    }

    @:allow(echoes.Entity) static inline function removeAllComponentsOf(id:Int) {
        if (status(id) == Active) {
            for (v in views) {
                v.removeIfExists(id);
            }
        }
        for (c in definedContainers) {
            c.remove(id);
        }
    }

    @:allow(echoes.Entity) static inline function printAllComponentsOf(id:Int):String {
        var ret = '#$id:';
        for (c in definedContainers) {
            if (c.exists(id)) {
                ret += '${ c.print(id) },';
            }
        }
        return ret.substr(0, ret.length - 1);
    }


}
