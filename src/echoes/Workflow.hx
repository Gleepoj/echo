package echoes;

import echoes.Entity.Status;
import echoes.core.AbstractView;
import echoes.core.ICleanableComponentContainer;
import echoes.core.ISystem;
import echoes.core.RestrictedLinkedList;

/**
 *  Workflow  
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
     * All systems that will be called when `update()` is called
     */
    public static var systems(default, null) = new RestrictedLinkedList<ISystem>();
    /**
     * All systems that will be called when `postUpdate()` is called.
     * Despite the name, "60fps" systems are not time-locked: they run each time `postUpdate()` is called
     * (typically once per rendered frame, with a variable dt). A system belongs to one list only.
     */
    public static var systems60fps(default, null) = new RestrictedLinkedList<ISystem>();


    #if echoes_profiling
    static var updateTime = .0;
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
        var ret = '# ( ${systems.length + systems60fps.length} ) { ${views.length} } [ ${entities.length} | ${idPool.length} ]'; // TODO version or something

        #if echoes_profiling
        ret += ' : ${updateTime + postUpdateTime} ms'; // total
        for (s in systems) {
            ret += '\n${ s.info('    ', 1) }';
        }
        if (systems60fps.length > 0) {
            ret += '\n    postUpdate : $postUpdateTime ms';
            for (s in systems60fps) {
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
     * Update 
     * @param dt deltatime
     */
    public static function update(dt:Float) {
        #if echoes_profiling
        var timestamp = Date.now().getTime();
        #end

        for (s in systems) {

            s.__update__(dt);

        }

        #if echoes_profiling
        updateTime = Std.int(Date.now().getTime() - timestamp);
        #end
    }

    /**
     * Updates the "60fps" systems (see `systems60fps`)
     * @param dt deltatime
     */
    public static function postUpdate(dt:Float) {
        #if echoes_profiling
        var timestamp = Date.now().getTime();
        #end

        for (s in systems60fps) {
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
        for (s in systems) {
            removeSystem(s);
        }
        for (s in systems60fps){
            remove60FpsSystem(s);
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
     * Adds the system to the workflow
     * @param s `System` instance
     */
    public static function addSystem(s:ISystem) {
        if (!hasSystem(s) && !has60FpsSystem(s)) {
            systems.add(s);
            s.__activate__();
        }
    }

    /**
     * Adds the system to the workflow, updated by `postUpdate()` (see `systems60fps`)
     * @param s `System` instance
     */
    public static function add60FpsSystem(s:ISystem) {
        if (!hasSystem(s) && !has60FpsSystem(s)) {
            systems60fps.add(s);
            s.__activate__();
        }
    }
    /**
     * Removes the system from the workflow
     * @param s `System` instance
     */
    public static function removeSystem(s:ISystem) {
        if (hasSystem(s)) {
            s.__deactivate__();
            systems.remove(s);
        }
    }

    public static function remove60FpsSystem(s:ISystem) {
        if (has60FpsSystem(s)) {
            s.__deactivate__();
            systems60fps.remove(s);
        }
    }

    /**
     * Returns `true` if the system is added to the workflow, otherwise returns `false`  
     * @param s `System` instance
     * @return `Bool`
     */
    public static function hasSystem(s:ISystem):Bool {
        return systems.exists(s);
    }

    public static function has60FpsSystem(s:ISystem):Bool {
        return systems60fps.exists(s);
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
