////////////////////////////////////////////////////////////////////////////////
//
//  ADOBE SYSTEMS INCORPORATED
//  Copyright 2008 Adobe Systems Incorporated
//  All Rights Reserved.
//
//  NOTICE: Adobe permits you to use, modify, and distribute this file
//  in accordance with the terms of the license agreement accompanying it.
//
////////////////////////////////////////////////////////////////////////////////

package spark.effects.supportClasses
{
import flash.events.TimerEvent;
import flash.utils.Timer;

import mx.core.IVisualElement;
import mx.core.IVisualElementContainer;
import mx.core.UIComponent;
import mx.core.mx_internal;
import mx.effects.EffectInstance;
import mx.events.EffectEvent;
import mx.resources.IResourceManager;
import mx.resources.ResourceManager;
import mx.styles.IStyleClient;

import spark.effects.KeyFrame;
import spark.effects.MotionPath;
import spark.effects.SimpleMotionPath;
import spark.effects.animation.Animation;
import spark.effects.animation.IAnimationTarget;
import spark.effects.easing.IEaser;
import spark.effects.interpolation.IInterpolator;

use namespace mx_internal;

//--------------------------------------
//  Other metadata
//--------------------------------------

[ResourceBundle("sparkEffects")]

/**
 * The AnimateInstance class implements the instance class for the
 * Animate effect. Flex creates an instance of this class when
 * it plays a Animate effect; you do not create one yourself.
 *  
 *  @langversion 3.0
 *  @playerversion Flash 10
 *  @playerversion AIR 1.5
 *  @productversion Flex 4
 */
public class AnimateInstance extends EffectInstance implements IAnimationTarget
{
    public var animation:Animation;
    
    public function AnimateInstance(target:Object)
    {
        super(target);
    }

    //--------------------------------------------------------------------------
    //
    //  Variables
    //
    //--------------------------------------------------------------------------
    /**
     *  Tracks whether each property of the target is an actual 
     *  property or a style. We determine this dynamically by
     *  simply checking whether the property is 'in' the target.
     *  If not, we check whether it is a valid style, and otherwise
     *  throw an error.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    private var isStyleMap:Object = new Object();
    
    /**
     *  @private.
     *  Used internally to hold the value of the new playhead position
     *  if the animation doesn't currently exist.
     */
    private var _seekTime:Number = 0;

    private var reverseAnimation:Boolean;
    
    private var needsRemoval:Boolean;

    /**
     * @private
     * Track number of update listeners for optimization purposes
     */
    private var numUpdateListeners:int = 0;
    
    
    /**
     *  @private
     *  Used for accessing localized Error messages.
     */
    private var resourceManager:IResourceManager =
                                    ResourceManager.getInstance();
    
    /**
     * @private
     * Cache these values when disabling constraints, to correctly reset
     * width/height values when we finish
     */
    private var oldWidth:Number;
    private var oldHeight:Number;

    //--------------------------------------------------------------------------
    //
    // Properties
    //
    //--------------------------------------------------------------------------

    private var _motionPaths:Array;
    /**
     * An array of SimpleMotionPath objects, each of which holds the
     * name of the property being animated and the values that the property
     * will take on during the animation.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get motionPaths():Array
    {
        return _motionPaths;
    }
    public function set motionPaths(value:Array):void
    {
        // Only set the list to the given value if we have a 
        // null list to begin with. Otherwise, we've already
        // set up the list once and don't need to do it again
        // (for example, in a repeating effect).
        if (!_motionPaths)
            _motionPaths = value;
    }
    
    /**
     * This flag indicates whether a subclass would like their target to 
     * be automatically kept around during a transition and removed when it
     * finishes. This capability applies specifically to effects like
     * Fade which act on targets that go away at the end of the
     * transition and removes the need to supply a RemoveAction or similar
     * effect to manually keep the item around and remove it when the
     * transition completes. In order to use this capability, subclasses
     * should set this variable to true and also expose the "parent"
     * property in their affectedProperties array so 
     * that the effect instance has enough information about the target
     * and container to do the job.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    protected var autoRemoveTarget:Boolean = false;
        
    /**
     * @copy spark.effects.Animate#disableConstraints
     */
    public var disableConstraints:Boolean;    

    /**
     * @copy spark.effects.Animate#disableLayout
     */
    public var disableLayout:Boolean;
    
    private var _easer:IEaser;    
    public function set easer(value:IEaser):void
    {
        _easer = value;
    }
    public function get easer():IEaser
    {
        return _easer;
    }
    
    private var _interpolator:IInterpolator;
    public function set interpolator(value:IInterpolator):void
    {
        _interpolator = value;
        
    }
    public function get interpolator():IInterpolator
    {
        return _interpolator;
    }
    
    private var _repeatBehavior:String;
    public function set repeatBehavior(value:String):void
    {
        _repeatBehavior = value;
    }
    public function get repeatBehavior():String
    {
        return _repeatBehavior;
    }
            
    //----------------------------------
    //  playReversed
    //----------------------------------

    /**
     *  @private
     */
    override mx_internal function set playReversed(value:Boolean):void
    {
        super.playReversed = value;
        
        if (value && animation)
            animation.reverse();
        
        reverseAnimation = value;
    }

    //--------------------------------------------------------------------------
    //
    //  Overridden methods
    //
    //--------------------------------------------------------------------------

    //----------------------------------
    //  playheadTime
    //----------------------------------
    
    /**
     *  @inheritDoc
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    override public function get playheadTime():Number 
    {
        return animation ? animation.playheadTime : 0;
    }
    /**
     * @private
     */
    override public function set playheadTime(value:Number):void
    {
        if (animation)
            animation.seek(value, true);
        else
            _seekTime = value;
    } 
    

    /**
     *  @private
     */
    override public function pause():void
    {
        super.pause();
        
        if (animation)
            animation.pause();
    }

    /**
     *  @private
     */
    override public function stop():void
    {
        super.stop();
        
        if (animation)
            animation.stop();
    }   
    
    /**
     *  @private
     */
    override public function resume():void
    {
        super.resume();
    
        if (animation)
            animation.resume();
    }
        
    /**
     *  @private
     */
    override public function reverse():void
    {
        super.reverse();
    
        if (animation)
            animation.reverse();
        
        reverseAnimation = !reverseAnimation;
    }
    
    /**
     *  Interrupts an effect that is currently playing,
     *  and immediately jumps to the end of the effect.
     *  Calls the <code>Tween.endTween()</code> method
     *  on the <code>tween</code> property. 
     *  This method implements the method of the superclass. 
     *
     *  <p>If you create a subclass of TweenEffectInstance,
     *  you can optionally override this method.</p>
     *
     *  <p>The effect dispatches the <code>effectEnd</code> event.</p>
     *
     *  @see mx.effects.EffectInstance#end()
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    override public function end():void
    {
        // Jump to the end of the animation.
        if (animation)
        {
            animation.end();
            animation = null;
        }

        super.end();
    }
        
    //--------------------------------------------------------------------------
    //
    // Methods
    //
    //--------------------------------------------------------------------------

    /**
     *  @copy mx.effects.IEffectInstance#startEffect()
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    override public function startEffect():void
    {  
        // This override removes EffectManager.effectStarted() to avoid use of
        // mx_internal. New effects are not currently triggerable, so
        // this should not matter
                 
        if (target is UIComponent)
        {
            UIComponent(target).effectStarted(this);
        }

        if (autoRemoveTarget)
            addDisappearingTarget();

        play();
    }
    
    /**
     * Starts this effect. Performs any final setup for each property
     * from/to values and starts an Animation that will update that property.
     * 
     * @private
     */
    override public function play():void
    {
        super.play();

        if (!motionPaths || motionPaths.length == 0)
        {
            // nothing to do; at least schedule the effect to end after
            // the specified duration
            var timer:Timer = new Timer(duration, 1);
            timer.addEventListener(TimerEvent.TIMER, noopAnimationHandler);
            timer.start();
            return;
        }
            
        isStyleMap = new Array(motionPaths.length);        
    
        // TODO (chaase): avoid setting up animations on properties whose
        // from/to values are the same. Not worth the cycles, but also want
        // to avoid triggering any side effects when we're not actually changing
        // values
        var i:int;
        var j:int;
        for (i = 0; i < motionPaths.length; ++i)
        {
            var mp:MotionPath = MotionPath(motionPaths[i]);
            // TODO (chaase): should we push this keyframe-init logic
            // into the MotionPath class instead?
            
            var keyframes:Array = motionPaths[i].keyframes;
            if (!keyframes)
                continue;
            // Create an initial (time==0) value if necessary 
            if (keyframes[0].time > 0)
            {
                keyframes.splice(0, 0, new KeyFrame(0, null));
                keyframes[0].timeFraction = 0;
            }
            if (interpolator)
                mp.interpolator = interpolator;
            // adjust effect duration to be the max of all MotionPath keyframe times
            // TODO (chaase): Currently we do not adjust *down* for smaller duration
            // MotionPaths. This is because we do not distinguish between
            // SimpleMotionPath objects (which are created with fake durations of 1,
            // knowing that they will derive their duration from their effects) and
            // actual keyframe-based MotionPaths.
            for (j = 0; j < keyframes.length; ++j)
                if (isNaN(keyframes[j].time))
                    keyframes[j].time = duration;
                else
                    duration = Math.max(duration, keyframes[j].time);

        }
        for (i = 0; i < motionPaths.length; ++i)
            motionPaths[i].scaleKeyframes(duration);

        animation = new Animation(duration);
        animation.animationTarget = this;
        animation.motionPaths = motionPaths;
        
        if (_seekTime > 0)
            animation.seek(_seekTime);
        if (reverseAnimation)
            animation.playReversed = true;
        animation.interpolator = interpolator;
        animation.repeatCount = repeatCount;
        animation.repeatDelay = repeatDelay;
        animation.repeatBehavior = repeatBehavior;
        animation.easer = easer;
        animation.startDelay = startDelay;
        
        animation.play();
          
        // TODO (chaase): there may be a better way to organize the 
        // animations for each property. For example, we could use 
        // an animation of a single value from 0 to 1 and then update each
        // property based on that elapsed fraction.
    }

    /**
     * Set the values in the given array on the properties held in our
     * motionPaths array. This is called by the update and end 
     * functions, which are called by the Animation during the animation.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    protected function applyValues(anim:Animation):void
    {
        for (var i:int = 0; i < motionPaths.length; ++i)
        {
            var prop:String = motionPaths[i].property;
            setValue(prop, anim.currentValue[prop]);
        }
    }
    
    // TODO (chaase): This function appears in multiple places. Maybe
    // put it in some util class instead?
    /**
     * @private
     * 
     * Utility function to determine whether a given value is 'valid',
     * which means it's either a Number and it's not NaN, or it's not
     * a Number and it's not null
     */
    private function isValidValue(value:Object):Boolean
    {
        return ((value is Number && !isNaN(Number(value))) ||
            (!(value is Number) && value !== null));
    }
    
    /**
     * Walk the motionPaths looking for null values. A null indicates
     * that the value should be replaced by the current value or one that
     * is calculated from the other value and a supplied delta value.
     * 
     * @return Boolean whether this call changed any values in the list
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    private function finalizeValues():Boolean
    {
        var changedValues:Boolean = false;
        var j:int;
        var prevValue:Object;
        for (var i:int = 0; i < motionPaths.length; ++i)
        {
            var motionPath:MotionPath = 
                MotionPath(motionPaths[i]);
            // set the first value (if invalid) to the current value
            // in the target
            var keyframes:Array = motionPath.keyframes;
            if (!keyframes || keyframes.length == 0)
                continue;
            if (!isValidValue(keyframes[0].value))
            {
                if (keyframes.length > 0 &&
                    isValidValue(keyframes[1].valueBy) &&
                    isValidValue(keyframes[1].value))
                {
                    keyframes[0].value = motionPath.interpolator.decrement(
                        keyframes[1].value, keyframes[1].valueBy);
                }
                else
                {
                    keyframes[0].value = getCurrentValue(motionPath.property);
                }
            }
            // set any other invalid values based on information in surrounding
            // keyframes
            prevValue = keyframes[0].value;
            for (j = 1; j < keyframes.length; ++j)
            {
                var kf:KeyFrame = KeyFrame(keyframes[j]);
                if (!isValidValue(kf.value))
                {
                    if (isValidValue(kf.valueBy))
                        kf.value = motionPath.interpolator.increment(prevValue, kf.valueBy);
                    else
                    {
                        // if next keyframe has value and valueBy, use them
                        if (j <= (keyframes.length - 2) &&
                            isValidValue(keyframes[j+1].value) &&
                            isValidValue(keyframes[j+1].valueBy))
                        {
                            kf.value = motionPath.interpolator.decrement(
                                keyframes[j+1].value, keyframes[j+1].valueBy);
                        }
                        else if (j == (keyframes.length - 1) &&
                            propertyChanges &&
                            propertyChanges.end[motionPath.property] !== undefined)
                        {
                            // special case for final keyframe - use state value if it exists
                            kf.value = propertyChanges.end[motionPath.property];
                        }
                        else
                        {
                            // otherwise, just use previous keyframe value
                            kf.value = prevValue;
                        }
                    }
                }
                prevValue = kf.value;
            }
        }
        return changedValues;
        
    }

    /**
     * This function is called by subclasses during the play() function
     * to add an animation to the current set of <code>motionPaths</code>.
     * The animation will be set up on the named constraint if the constraint
     * is in the <code>propertyChanges</code> array (which is only true during
     * transitions for properties/styles exposed by the effect) and the
     * value of that constraint is different between the start and end states.
     */ 
    protected function setupConstraintAnimation(constraintName:String):void
    {
        var startVal:* = propertyChanges.start[constraintName];
        var endVal:* = propertyChanges.end[constraintName];
        if (startVal !== undefined && endVal !== undefined &&
            startVal !== null && endVal !== null &&
            startVal != endVal)
        {
            motionPaths.push(new SimpleMotionPath(constraintName, startVal, endVal));
        }
    }

    /**
     * Called internally to handle start events for the animation.
     * If you override this method, ensure that you call the super method.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function animationStart(animation:Animation):void
    {
        // Wait until the underlying Animation actually starts (after
        // any startDelay) to cache constraints and disable layout. This
        // avoids problems with doing this too early and affecting other
        // effects that are running before this one.
        if (disableConstraints)
            cacheConstraints();
        if (disableLayout)
            setupParentLayout(false);
            
        finalizeValues();

        // TODO (chaase): Consider putting AnimateInstance (and subclass's) 
        // play() functionality (the setup and playing of the Animation object)
        // into startEffect(), calling play() from here, and not overriding
        // play() at all.
    }
    
    /**
     * Called internally to handle update events for the animation.
     * If you override this method, ensure that you call the super method.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function animationUpdate(animation:Animation):void
    {
        applyValues(animation);
        if (numUpdateListeners > 0)
        {
            // Only bother dispatching this event if there are listeners. This avoids
            // unnecessary overhead for the common case of no listeners on this frequent
            // event
            var event:EffectEvent = new EffectEvent(EffectEvent.EFFECT_UPDATE);
            event.effectInstance = this;
            dispatchEvent(event);
        }
    }
    
    /**
     * Called internally to handle repeat events for the animation.
     * If you override this method, ensure that you call the super method.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function animationRepeat(animation:Animation):void
    {
        var event:EffectEvent = new EffectEvent(EffectEvent.EFFECT_REPEAT);
        event.effectInstance = this;
        dispatchEvent(event);
    }    

    /**
     * Called internally to handle end events for the animation. 
     * If you override this method, ensure that you call the super method.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function animationEnd(animation:Animation):void
    {
        if (disableConstraints)
            reenableConstraints();
        if (disableLayout)
            setupParentLayout(true);
        finishEffect();
    }

    private function noopAnimationHandler(event:TimerEvent):void
    {
        finishEffect();
    }

    /**
     * @private
     * Track number of listeners to update event for optimization purposes
     */
    override public function addEventListener(type:String, listener:Function, 
        useCapture:Boolean=false, priority:int=0, 
        useWeakReference:Boolean=false):void
    {
        super.addEventListener(type, listener, useCapture, priority, 
            useWeakReference);
        if (type == EffectEvent.EFFECT_UPDATE)
            ++numUpdateListeners;
    }
    
    /**
     * @private
     * Track number of listeners to update event for optimization purposes
     */
    override public function removeEventListener(type:String, listener:Function, 
        useCapture:Boolean=false):void
    {
        super.removeEventListener(type, listener, useCapture);
        if (type == EffectEvent.EFFECT_UPDATE)
            --numUpdateListeners;
    }
    
    /**
     *  @copy mx.effects.IEffectInstance#finishEffect()
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    override public function finishEffect():void
    {
        if (autoRemoveTarget)
            removeDisappearingTarget();
        super.finishEffect();
    }

    /**
     * Adds a target which is not in the state we are transitioning
     * to. This is the partner of removeDisappearingTarget(), which removes
     * the target when this effect is finished if necessary.
     * Note that if a RemoveAction effect is playing in a CompositeEffect,
     * then the adding/removing is already happening and this function
     * will noop the add.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    private function addDisappearingTarget():void
    {
        needsRemoval = false;
        if (propertyChanges)
        {
            // Check for non-null parent ensures that we won't double-remove
            // items, such as if there is a RemoveAction effect working on
            // the same target
            if ("parent" in target && !target.parent)
            {
                var parentStart:* = propertyChanges.start["parent"];;
                var parentEnd:* = propertyChanges.end["parent"];;
                if (parentStart && !parentEnd)
                {
                    if (parentStart is IVisualElementContainer)
                        IVisualElementContainer(parentStart).addElement(target as IVisualElement);
                    else
                        parentStart.addChild(target);
                    needsRemoval = true;
                }
            }
        }
    }

    /**
     * Removes a target which is not in the state we are transitioning
     * to. This is the partner of addDisappearingTarget(), which re-adds
     * the target when this effect is played if necessary.
     * Note that if a RemoveAction effect is playing in a CompositeEffect,
     * then the adding/removing is already happening and this function
     * will noop the removal.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    private function removeDisappearingTarget():void
    {
        if (needsRemoval && propertyChanges)
        {
            // Check for non-null parent ensures that we won't double-remove
            // items, such as if there is a RemoveAction effect working on
            // the same target
            if ("parent" in target && target.parent)
            {
                var parentStart:* = propertyChanges.start["parent"];;
                var parentEnd:* = propertyChanges.end["parent"];;
                if (parentStart && !parentEnd)
                {
                    if (parentStart is IVisualElementContainer)
                        IVisualElementContainer(parentStart).removeElement(target as IVisualElement);
                    else
                        parentStart.removeChild(target);
                }
            }
        }
    }

    private var constraintsHolder:Object;
    
    // TODO (chaase): Use IConstraintClient for this
    private function reenableConstraint(name:String):void
    {
        var value:* = constraintsHolder[name];
        if (value !== undefined)
        {
            if (name in target)
                target[name] = value;
            else
                target.setStyle(name, value);
            delete constraintsHolder[name];
        }
    }
    
    private function reenableConstraints():void
    {
        // Only bother if constraintsHolder is non-null; otherwise
        // there must have been no constraints to worry about
        if (constraintsHolder)
        {
            // TODO EGeorgie: add support for 'baseline' constraint, when the new layouts support it.
            var left:* = reenableConstraint("left");
            var right:* = reenableConstraint("right");
            var top:* = reenableConstraint("top");
            var bottom:* = reenableConstraint("bottom");
            reenableConstraint("horizontalCenter");
            reenableConstraint("verticalCenter");
            reenableConstraint("baseline");
            constraintsHolder = null;
            if (left != undefined && right != undefined && "explicitWidth" in target)
                target.explicitWidth = oldWidth;            
            if (top != undefined && bottom != undefined && "explicitHeight" in target)
                target.explicitHeight = oldHeight;
        }
    }
    
    // TODO (chaase): Use IConstraintClient for this
    private function cacheConstraint(name:String):*
    {
        var isProperty:Boolean = (name in target);
        var value:*;
        if (isProperty)
            value = target[name];
        else
            value = target.getStyle(name);
        if (!isNaN(value) && value != null)
        {
            if (!constraintsHolder)
                constraintsHolder = new Object();
            constraintsHolder[name] = value;
            // Now disable it - it will be re-enabled when effect finishes
            if (isProperty)
                target[name] = NaN;
            else if (target is IStyleClient)
                target.setStyle(name, undefined);
        }
        return value;
    }
    
    private function cacheConstraints():void
    {
        var left:* = cacheConstraint("left");
        var right:* = cacheConstraint("right");
        var top:* = cacheConstraint("top");
        var bottom:* = cacheConstraint("bottom");
        cacheConstraint("verticalCenter");
        cacheConstraint("horizontalCenter");
        cacheConstraint("baseline");
        if (left != undefined && right != undefined && "explicitWidth" in target)
        {
            var w:Number = target.width;    
            oldWidth = target.explicitWidth;
            target.width = w;
        }
    
        if (top != undefined && bottom != undefined && "explicitHeight" in target)
        {
            var h:Number = target.height;
            oldHeight = target.explicitHeight;
            target.height = h;
        }
    }

    /**
     * Utility function to handle situation where values may be queried or
     * set on the target prior to completely setting up the effect's
     * motionPaths data values (from which the styleMap is created)
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    protected function setupStyleMapEntry(property:String):void
    {
        // TODO (chaase): Find a better way to set this up just once
        if (isStyleMap[property] == undefined)
        {
            if (property in target)
            {
                isStyleMap[property] = false;
            }
            else
            {
                try {
                    target.getStyle(property);
                    isStyleMap[property] = true;
                }
                catch (err:Error)
                {
                    throw new Error(resourceManager.getString("sparkEffects", 
                        "propNotPropOrStyle", [property, target, err])); 
                }
                // TODO: check to make sure that the throw above won't
                // let the code flow get to here
            }            
        }
    }
    
    /**
     *  Utility function that sets the named property on the target to
     *  the given value. Handles setting the property as either a true
     *  property or a style.
     *  @private
     */
    protected function setValue(property:String, value:Object):void
    {
        // TODO (chaase): Find a better way to set this up just once
        setupStyleMapEntry(property);
        if (!isStyleMap[property])
            target[property] = value;
        else
            target.setStyle(property, value);
    }

    /**
     *  Utility function that gets the value of the named property on 
     *  the target. Handles getting the value of the property as either a true
     *  property or a style.
     *  @private
     */
    protected function getCurrentValue(property:String):*
    {
        // TODO (chaase): Find a better way to set this up just once
        setupStyleMapEntry(property);
        if (!isStyleMap[property])
            return target[property];
        else
            return target.getStyle(property);
    }

    /**
     * Enables or disables autoLayout in the target's container.
     * This is used to disable layout during the course of an animation,
     * and to re-enable it when the animation finishes.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    private function setupParentLayout(enable:Boolean):void
    {
        var parent:* = null;
        if ("parent" in target && target.parent)
        {
            parent = target.parent;
        }
        
        if (parent && ("autoLayout" in parent))
            parent.autoLayout = enable;
    }
}
}
