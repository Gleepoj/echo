package echos;

/**
 * System  
 * 
 * Functions with `@update` (or `@up`, or `@u`) meta are called for each entity that contains all the defined components.  
 * So, a function like 
 * ```
 * @u function f(a:A, b:B, entity:Entity)
 * ```
 * does a two things: 
 * - Defines and initializes a `View<A, B>` (if the `View<A, B>` has not been previously defined)  
 * - Creates a loop in the system update method  
 * ```
 * for (entity in viewOfAB.entities) {  
 *     f(entity.get(A), entity.get(B), entity);  
 * }  
 * ```
 * 
 * Functions with `@added`, `@ad`, `@a` meta become callbacks that will be called on each entity to be assembled by the view.  
 * Functions with `@removed`, `@rm`, `@r` does the same but when entity is removed.  
 * 
 * `View` can always be defined manually (no initialization required) in the system.  
 * If you want to access `View` from the outside, you can make it static.  
 *  
 * @author https://github.com/deepcake
 */
#if !macro
@:autoBuild(echos.core.macro.SystemBuilder.build())
#end
class System {


    @:allow(echos.Workflow) function __activate__() {
        onactivate();
    }

    @:allow(echos.Workflow) function __deactivate__() {
        ondeactivate();
    }

    @:allow(echos.Workflow) function __update__(dt:Float) {
        // macro
    }


    /**
     * Calls when system is added to the workflow
     */
    public function onactivate() { }

    /**
     * Calls when system is removed from the workflow
     */
    public function ondeactivate() { }


    public function toString():String return 'System';


}
