package echos;

/**
 * System  
 * `@update`, `@up`, `@u` - calls on every appropriated entity  
 * `@added`, `@ad`, `@a` - added callback  
 * `@removed`, `@rm`, `@r` - removed callback  
 *  
 * @author https://github.com/deepcake
 */
#if !macro
@:autoBuild(echos.macro.SystemMacro.build())
#end
class System {


    @:allow(echos.Workflow) function __activate() {
        onactivate();
    }

    @:allow(echos.Workflow) function __deactivate() {
        ondeactivate();
    }

    @:allow(echos.Workflow) function __update(dt:Float) {
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
