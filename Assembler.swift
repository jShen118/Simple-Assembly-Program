//
//  Assembler.swift
//  Simple Assembly Program
//
//  Created by Joshua Shen on 5/19/19.
//  Copyright © 2019 Joshua Shen. All rights reserved.
//

import Foundation


struct Assembler{
    var programs = [Program]()
    var userInput = ""
    init() {}
    
    mutating func read(_ path: String)-> Bool {
        if Support.readTextFile(path).fileText == nil {
            print(Support.readTextFile(path).message!)
            return false
        }
        programs.append(Program(path))
        let fileContent = Support.readTextFile(path).fileText!
        let inputCode = Support.splitStringIntoLines(fileContent)
        for i in 0..<inputCode.count {
            //print("\(i + 1)     \(inputCode[i])")
            if inputCode[i].count > 0 {
                programs[getProgramIndex(path)!].lines.append(Line(i + 1, inputCode[i]))
            }
        }
        return true
    }
    
    mutating func assemble(_ pathSpecs: String, _ name: String) {
        let path = pathSpecs + name + ".txt"
        passOne(path)
        let pIndex = getProgramIndex(path)
        if pIndex == nil {return}
        if !programs[pIndex!].legal {
            print("...Assembly was unsuccessful"); return
        }
        passTwo(pathSpecs + name)
        print("...Assembly was successful")
    }
    
    func getProgramIndex(_ path: String)-> Int? {
        for i in 0..<programs.count {
            if programs[i].path == path {
                return i
            }
        }
        return nil
    }
    
    func printSymVal(_ path: String) {
        let pIndex = getProgramIndex(path)
        if pIndex == nil {print("Please assemble the program first"); return}
        print("Symbol table: \n")
        for (k, _) in programs[pIndex!].symVal {
            print("\(Support.buffer(Support.removeColon(k), 22)) \(programs[pIndex!].symVal[k]!)")
        }
    }
}

// PASS ONE
extension Assembler{
    //passOne makes symVal and checks for legality
    mutating func passOne(_ path: String) {
        if !read(path) {return}
        let pIndex = getProgramIndex(path)
        programs[pIndex!].legal = true
        makeSymVal(path, programs[pIndex!].lines)
        for l in programs[pIndex!].lines {
            print(l, terminator: "")
            if !isLegal(path, l).0 {programs[pIndex!].legal = false}
            print(isLegal(path, l).1)
        }
    }
    
    mutating func makeSymVal(_ path: String, _ lines: [Line]) { 
        let pIndex = getProgramIndex(path)
        var memLocation = -1 //to account for .start label address not taking up a space
        for l in lines {
            for i in 0..<l.tokens.count {
                switch l.tokens[i].type {
                case .LabelDefinition:
                    programs[pIndex!].symVal[l.chunks[i]] = memLocation
                    programs[pIndex!].valSym[memLocation] = l.chunks[i]
                case .ImmediateInteger: memLocation += 1
                case .ImmediateString: memLocation += l.chunks[i].count - 1
                case .ImmediateTuple: memLocation += 5
                case .Label: memLocation += 1
                case .Instruction: memLocation += 1
                case .Register: memLocation += 1
                default: memLocation += 0 //executed if .Directive or .BadToken, in which case no memory locations modified
                }
            }
        }
    }
    
    // returns (args are legal, error message)
    func isLegal(_ path: String, _ line: Line)-> (Bool, String) {
        let chunks = line.chunks
        let tokens = line.tokens
        if tokens.count >= 1 {
            switch tokens[0].type {
            case .Instruction: return validInstructionArgs(path, line, 0)
            case .Directive: return validDirectiveArg(line, 0)
            case .LabelDefinition:
                if tokens[1].type == .Instruction {return validInstructionArgs(path, line, 1)}
                if tokens[1].type == .Directive {return validDirectiveArg(line, 1)}
                return (false, "\n..........A Label Definition must be followed by an Instruction or a Directive")
            case .BadToken: return (false, "\n..........\(chunks[0]) is a Bad Token")
            default: return (false, "\n..........Line must start with an Instruction, .Start, or a Label Definition")
            }
        } else {return (true, "")} //to account for comment/blank lines
    }
    
    //(args are legal, error message), the start arg is the index of the instruction token
    func validInstructionArgs(_ path: String, _ line: Line, _ start: Int)-> (Bool, String) {
        let expected = AssemblerDictionary.instructionArgs[line.chunks[start]]
        if expected != nil{
            if line.tokens.count - start > expected!.count + 1 {return (false, "\n..........\(line.chunks[start]) has too many arguments")}
            for i in 0..<expected!.count {
                if expected![i] == .Label && !labelExists(path, line.chunks[i + start + 1]) {return (false, "\n..........Label \"\(line.chunks[start + i + 1])\" has not been defined")}
                if line.tokens[start + i + 1].type != expected![i] {
                    return (false, "\n..........Instruction \(line.chunks[start]) arguments are not as expected")
                }
            }
            return (true, "")
        }
        return (false, "")
    }
    
    //(args are legal, error message), the start arg is the index of the directive token
    func validDirectiveArg(_ line: Line, _ start: Int)-> (Bool, String) {
        let expected = AssemblerDictionary.directiveArgs[line.chunks[start]]
        if line.tokens.count - start != 2 {return (false, "\n..........Directives should take in one argument")}
        if line.tokens[start + 1].type == expected![0] {return (true, "")}
        return (false, "\n..........\(line.chunks[start]) should take in an \(expected![0])")
    }
    
    func labelExists(_ path: String, _ label: String)-> Bool {
        return programs[getProgramIndex(path)!].symVal[label + ":"] != nil
    }
}

// PASS TWO
extension Assembler {
    // pass two makes translates assembly to binary
    mutating func passTwo(_ pathNoTxt: String) {
        if !programs[getProgramIndex(pathNoTxt + ".txt")!].legal {return}
        translate(pathNoTxt + ".txt")
        Support.writeTextFile(pathNoTxt + ".bin" + ".txt", makeBin(pathNoTxt + ".txt"))
        Support.writeTextFile(pathNoTxt + ".lst" + ".txt", makeLst(pathNoTxt + ".txt"))
    }
    
    func makeBin(_ path: String)-> String {
        let pIndex = getProgramIndex(path)
        if pIndex == nil {return "Please assemble the program first"}
        var toReturn = "\(programs[pIndex!].length)"
        toReturn += "\n\(programs[pIndex!].start)"
        for i in 0..<programs[pIndex!].mem.count {toReturn += "\n\(programs[pIndex!].mem[i])"}
        toReturn += "\n\n"
        return toReturn
    }
    
    mutating func translate(_ path: String) {
        let pIndex = getProgramIndex(path)
        programs[pIndex!].mem = [Int]()
        for l in programs[pIndex!].lines {
            for i in 0..<l.tokens.count {
                switch l.tokens[i].type {
                case .Register: programs[pIndex!].mem.append(AssemblerDictionary.registers[l.chunks[i]]!)
                case .ImmediateString: for b in translateString(l.tokens[i].stringValue!) {programs[pIndex!].mem.append(b)}
                case .ImmediateInteger: programs[pIndex!].mem.append(l.tokens[i].intValue!)
                case .ImmediateTuple: for b in translateTuple(l.tokens[i]) {programs[pIndex!].mem.append(b)}
                case .Instruction: programs[pIndex!].mem.append(AssemblerDictionary.instructions[l.chunks[i]]!)
                case .Label: programs[pIndex!].mem.append(programs[pIndex!].symVal[l.chunks[i] + ":"]!)
                case .Directive: print("", terminator: "") //does nothing
                case .LabelDefinition: print("", terminator: "") //does nothing
                default: print("this should never be printed as pass one should vet for legality")
                }
            }
        }
        //.start location already at beginning due to label locations
        //being put into memory whenever they are encountered
        programs[pIndex!].start = programs[pIndex!].mem[0]
        programs[pIndex!].length = programs[pIndex!].mem.count - 1
        programs[pIndex!].mem.remove(at: 0)
    }
    // \0 _ 0 _ r\
    mutating func translateTuple(_ token: Token)->[Int] {
        var binary = [Int]()
        binary.append(token.tupleValue!.currentState) //cs
        binary.append(Support.characterToUnicodeValue(token.tupleValue!.inputCharacter))//ic
        binary.append(token.tupleValue!.newState) //ns
        binary.append(Support.characterToUnicodeValue(token.tupleValue!.outputCharacter)) //oc
        binary.append(token.tupleValue!.direction) //di
        return binary
    }
    
    mutating func translateString(_ string: String)->[Int] {
        var binary = [Int]()
        let stringChars = Array(string)
        binary.append(stringChars.count)
        for c in stringChars {
            binary.append(Support.characterToUnicodeValue(c))
        }
        return binary
    }
    
    
    func getIgnore(_ tokens: [Token])-> Int {
        var toIgnore = 0
        for t in tokens {
            if t.type == .LabelDefinition || t.type == .Directive {
                toIgnore += 1
            }
        }
        return toIgnore
    }
    
    func getMemContents(_ path: String, _ address: Int, _ l: Line)-> String {
        let pIndex = getProgramIndex(path)
        var memContents = ""
        if address >= programs[pIndex!].length {return "\n"}
        for n in 0..<l.tokens.count {
            switch l.tokens[n].type {
            case .ImmediateString:
                for i in 0..<programs[pIndex!].mem[address] {
                    if i <= 3 {
                        memContents += " \(programs[pIndex!].mem[address + i])"
                    }
                }
            case .ImmediateTuple:
                for i in 0..<4 {
                    memContents += " \(programs[pIndex!].mem[address + i])"
                }
            case .ImmediateInteger:
                memContents += " \(programs[pIndex!].mem[address + n - getIgnore(l.tokens)])"
            case .Label:
                if l.chunks[0] != ".start" && l.chunks[0] != ".Start" {
                    memContents += " \(programs[pIndex!].mem[address + n - getIgnore(l.tokens)])"
                }
            case .Instruction:
                memContents += " \(programs[pIndex!].mem[address + n - getIgnore(l.tokens)])"
            case .Register:
                memContents += " \(programs[pIndex!].mem[address + n - getIgnore(l.tokens)])"
            default: print("", terminator: "")
            }
        }
        return "\(memContents)"
    }
    
    func makeLst(_ path: String)-> String {
        let pIndex = getProgramIndex(path)
        if pIndex == nil {return "Please assemble the program first"}
        var toReturn = ""
        var memLocation = 0
        var memContents = " "
        for l in programs[pIndex!].lines {
            //must getMemContents before changing memLocation since memLocation when printed
            memContents = getMemContents(path, memLocation, l)
            toReturn += Support.buffer("\(memLocation): \(memContents)", 23) + l.lineText + "\n"
            for i in 0..<l.tokens.count {
                switch l.tokens[i].type {
                case .ImmediateString: memLocation += l.chunks[i].count - 1
                case .ImmediateTuple: memLocation += 5
                case .ImmediateInteger: memLocation += 1
                case .Label:
                    if l.chunks[i - 1] != ".start" && l.chunks[i - 1] != ".Start" {memLocation += 1}
                case .Instruction: memLocation += 1
                case .Register: memLocation += 1
                default: memLocation += 0
                }
            }
        }
        return toReturn
    }
}





