#!/usr/bin/env coffee
###
 * Entitas code generation
 *
 * Generate FSharp stubs for
 * use by ecs-fsharp in Unity
 *
###
fs = require('fs')
path = require('path')
mkdirp = require('mkdirp')
config = require("#{process.cwd()}/entitas.json")

getType = (arg) ->
  switch arg
    when 'number'   then 'float'
    when 'string'   then 'string'
    when 'boolean'  then 'bool'
    when 'any'      then 'Object'
    else arg

getDefault = (arg) ->
  switch arg
    when 'boolean'  then 'false'
    when 'string'   then '""'
    when 'number'   then '0.0f'
    when 'any'      then 'null'
    else arg
    

params = (args) ->
  sb = []
  for arg in args
    name = arg.split(':')[0]
    type = getType(arg.split(':')[1])
    sb.push "#{name}"
    
  sb.join(', ') 
  

module.exports =
#
# generate entity extensions
#
# @return none
#
  run: (flags...) ->

    sb = []
    ex = []
    sb.push "namespace #{config.namespace}"
    sb.push ""
    sb.push "open Entitas"
    sb.push "open System"
    sb.push "open System.Collections.Generic"
    sb.push "open Microsoft.FSharp.Reflection"
    
    ex.push "module #{config.namespace}Extensions"
    ex.push ""
    ex.push "open Entitas"
    ex.push "open #{config.namespace}"
    ex.push "open System"
    ex.push "open System.Collections.Generic"
    ex.push "open Microsoft.FSharp.Reflection"

    ###
     * Components Type Definitions
    ###
    for Name, properties of config.components
      name = Name[0].toLowerCase()+Name[1...]
      sb.push ""
      sb.push "[<AllowNullLiteral>]"
      sb.push "type #{Name}Component() ="
      sb.push "    inherit Component()"
      if properties is false 
        sb.push "    member val active = false with get, set"
      else
        for p in properties
          name = p.split(':')[0]
          value = getDefault(p.split(':')[1])
          sb.push "    member val #{name} = #{value} with get, set"
      
    ###
     * Systems Type Definitions
    ###
    for Name, interfaces of config.systems
      name = Name[0].toLowerCase()+Name[1...]
      sb.push ""
      sb.push "type #{Name}(world) ="
      
      found = false
      for iface in interfaces

        if 'IExecuteSystem' is iface
          sb.push "    interface IExecuteSystem with"
          sb.push "        member this.Execute() ="
          sb.push "            ()"
          found = true
          
        if 'IInitializeSystem' is iface
          sb.push "    interface IInitializeSystem with"
          sb.push "        member this.Initialize() ="
          sb.push "            ()"
          found = true

      sb.push "    class end" unless found 
    sb.push ""
               
    ###
     * Entity Extensions
    ###
    ex.push ""
    ###
     * Components List
    ###
    ex.push "let isNull x = match x with null -> true | _ -> false"
    ex.push ""
    ex.push "type ComponentId = "
    kc = 0
    for Name, properties of config.components
      name = Name[0].toLowerCase()+Name[1...]
      ex.push "  | #{Name} = #{++kc}"    
    ex.push "  | TotalComponents = #{++kc}"    
    ex.push ""
  
    for Name, properties of config.components
      name = Name[0].toLowerCase()+Name[1...];
      switch properties
        when false
          ex.push "type Entity with"     
          ex.push ""
          ex.push "    static member #{name}Component= new #{Name}Component()"
          ex.push ""
          ex.push "    member this.is#{Name}"
          ex.push "        with get() ="
          ex.push "            this.HasComponent(int ComponentId.#{Name})"
          ex.push "        and  set(value) ="
          ex.push "            if value <> this.is#{Name} then"
          ex.push "                this.AddComponent(int ComponentId.#{Name}, Entity.#{name}Component) |> ignore"
          ex.push "            else"
          ex.push "                this.RemoveComponent(int ComponentId.#{Name}) |> ignore"
          ex.push ""
          ex.push "    member this.Is#{Name}(value) ="
          ex.push "        this.is#{Name} <- value"
          ex.push "        this"
          ex.push ""
          ex.push "type Matcher with "
          ex.push "    static member #{Name} with get() = Matcher.AllOf(int ComponentId.#{Name}) "
          ex.push ""
          
        else
          ex.push "type Entity with"
          ex.push "    member this.#{name}"
          ex.push "        with get() = this.GetComponent(int ComponentId.#{Name}):?>#{Name}Component"
          ex.push ""
          ex.push "    member this.has#{Name}"
          ex.push "        with get() = this.HasComponent(int ComponentId.#{Name})"
          ex.push ""
          ex.push "    member this._#{name}ComponentPool"
          ex.push "         with get() = new Stack<#{Name}Component>()"
          ex.push ""
          ex.push "    member this.Clear#{Name}ComponentPool() ="
          ex.push "        this._#{name}ComponentPool.Clear()"
          ex.push ""
          ex.push "    member this.Add#{Name}(#{params(properties)}) ="
          ex.push "        let mutable c = "
          ex.push "          match this._#{name}ComponentPool.Count with"
          ex.push "          | 0 -> new #{Name}Component()"
          ex.push "          | _ -> this._#{name}ComponentPool.Pop()"
          for p in properties
            ex.push "        c.#{p.split(':')[0]} <- #{p.split(':')[0]};"
          ex.push "        this.AddComponent(int ComponentId.#{Name}, c)"
          ex.push ""
          ex.push "    member this.Replace#{Name}(#{params(properties)}) ="
          ex.push "        let previousComponent = if this.has#{Name} then this.#{name} else null"
          ex.push "        let mutable c = "
          ex.push "          match this._#{name}ComponentPool.Count with"
          ex.push "          | 0 -> new #{Name}Component()"
          ex.push "          | _ -> this._#{name}ComponentPool.Pop()"
          for p in properties
            ex.push "        c.#{p.split(':')[0]} <- #{p.split(':')[0]};"
          ex.push "        this.ReplaceComponent(int ComponentId.#{Name}, c) |> ignore"
          ex.push "        if not(isNull(previousComponent)) then"
          ex.push "            this._#{name}ComponentPool.Push(previousComponent)"
          ex.push "        this"
          ex.push ""
          ex.push "    member this.Remove#{Name}() ="
          ex.push "        let c = this.#{name}"
          ex.push "        this.RemoveComponent(int ComponentId.#{Name}) |> ignore"
          ex.push "        this._#{name}ComponentPool.Push(c)"
          ex.push ""
          ex.push "type Matcher with "
          ex.push "    static member #{Name} with get() = Matcher.AllOf(int ComponentId.#{Name}) "
          ex.push ""
          
               
    if flags.indexOf('-x') 
      console.log sb.join('\n')
    else           
      console.log ex.join('\n')          
    
    
    # mkdirp.sync path.join(process.cwd(), 'build/')
    # fs.writeFileSync(path.join(process.cwd(), "build/#{Name}.fs"), sb.join('\n'))
