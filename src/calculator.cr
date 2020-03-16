module Calculator
    VERSION = "0.1.0"
    class Operator
        property symbol, priority, pos
        getter symbol, priority, pos
        def initialize(@symbol : Char, @priority : Int32, @pos : Int32)
        end
    end

    class Function
        #start is relative to parent
        property original_length : Int32
        getter name, start, string, original_length, abs_pos
        def initialize(name : String, string : String, start : Int32, abs_pos : Int32)
            @func_parts = Array(Function).new
            @operators = Array(Operator).new
            @string = string
            @name = name
            @start = start
            @original_length = string.size
            @values = Array(Float64 | Int32 ).new
            @abs_pos = abs_pos
        end

        def set_func_parts(parts)
            @func_parts = parts
        end

        def max_operator_index()
            prio = -1
            max_index = -1
            @operators.size.times do |index|
            priority = @operators[index].priority
                if priority > prio
                    prio = priority
                    max_index = index
                end
            end
            max_index
        end

        def value
            while @operators.size > 0
                index = max_operator_index()
                @values[index] = Calculator.calculate @values[index], @values[index + 1], @operators[index].symbol
                @values.delete_at index+1
                @operators.delete_at index
            end
            Calculator.apply_function(@values[0], @name)
        end

        def build
            # Make functions
            @func_parts.each do |part|
                part.build
                calculated_start = part.start - part.name.size - 1
                offset = part.start + part.original_length + 1
                @string = @string[0, calculated_start] + part.value.to_s + @string[offset, @string.size - offset]
            end

            # Make Operators
            operators = Calculator.find_operators @string
            operators.each do |pos, priority|
                @operators << Operator.new @string[pos], priority, pos 
            end
            @operators = @operators.sort { |a,b|
                a.pos <=> b.pos
            }

            # Make value parts
            last = 0
            @operators.each do |operator|
                pos = operator.pos
                @values << Calculator.parse_number @string[last, pos - last]
                last = pos + 1
            end
            @values << Calculator.parse_number @string[last, @string.size - last]
        end

        def length
            @string.size
        end
    end

    @@maxOperator = 3
    @@numbers = "0123456789πe."
    @@special = "πe√"
    @@placeholder = ''

    def self.calculate(input : String)
        input = self.transform input
        functions = self.find_functions input
        function = self.function_children Function.new("", input, 0, 0), functions.keys.reverse, input
        function.build
        function.value
    end

    # Determines children and their position relative to their parent
    def self.function_children(func, functions, input)
        children = Array(Function).new
        temp_children = Array(Tuple(Int32, Int32, String)).new
        child_func = Function.new("empty", "", 0, 0)
        index = input.size + 1

        functions.each do |key|
            if key[0] < index
                if child_func.name != "empty"
                    children << self.function_children child_func, temp_children, input
                end
                child_func = Function.new(key[2], input[key[0], key[1] - key[0]], key[0] - func.abs_pos, key[0])
                temp_children.clear
                index = key[0]
            else   
                temp_children << key
            end
        end

        if child_func.name != "empty"
            children << self.function_children child_func, temp_children, input
        end
        func.set_func_parts children
        func
    end

    def self.apply_function(number, funcName)
        case funcName
            when "sin"
                Math.sin number
            when "cos"
                Math.cos number
            when "tan"
                Math.tan number
            else
                number
        end
    end

    def self.calculate(n1, n2, operator)
        case operator
            when '+'
                n1 + n2
            when '-'
                n1 - n2
            when '*'
                n1 * n2
            when '/'
                n1 / n2
            when '√'
                n2**(1/n1)
            when '^'
                n1**n2
            when '%'
                if (n1.is_a?(Int) && n2.is_a?(Int))
                    n1%n2
                else
                    puts "Can't calculate the modulo, did not find Integers"
                    0
                end
            else
                0
        end
    end

    def self.parse_number(input)
        if input == "π"
            3.1415926535897932384626433832795028841
        elsif input == "e"
            LibM.exp_f64(1.0)
        elsif input.size == 0
            0
        elsif input.includes?('.')
            input.to_f
        else
            input.to_i
        end
    end


    def self.is_number?(input : Char)
        @@numbers.includes?(input)
    end


    #   Finds functions; Returns the begin (inclusive), end (exclusive) and name as a Tuple 
    #   The corresponding value in the HashMap is the priority
    def self.find_functions(input)
        functionsHash = Hash(Tuple(Int32, Int32, String), Int32).new
        bracketBonus = 0

        tempMap = Hash(Int32, Tuple(Int32, String)).new # store opened brackets with start priority --> pos and name

        input.each_char_with_index do |char, index|
            if char == '('
                j = index
                # Find the name
                while j > 0
                    j-=1
                    temp_c = input[j]
                    if self.is_operator?(temp_c) != -1 || temp_c == '('
                        break
                    end
                end
                start = index + 1
                name = input[j + 1..Math.max(0,index-1)]
                tempMap[bracketBonus] = {start,name}
                bracketBonus += @@maxOperator
            elsif char == ')'
                bracketBonus -= @@maxOperator
                tuple = tempMap[bracketBonus]
                functionsHash[{tuple[0], index, tuple[1]}] = bracketBonus
                tempMap.delete bracketBonus
            end
        end
        functionsHash
    end

    def self.find_operators(input : String)
        operatorHash = Hash(Int32, Int32).new
        bracketBonus = 0
        input.each_char_with_index do |char, index|
            if char == '('
                bracketBonus += @@maxOperator
            elsif char == ')'
                bracketBonus -= @@maxOperator
            else
                res = self.is_operator? char
                if res > -1 && index > 0 && (char != '-' || self.is_operator?(input[index-1]) == -1)
                    operatorHash[index] = res + bracketBonus
                end# 0, 3
            end
        end
        operatorHash
    end


    def self.gsub(input : String, hash : Hash(String | Regex, _))
        hash.each do |key, value|
            input = input.gsub(key, value)
        end
        input
    end


    def self.transform(input : String) : String
        self.gsub(
            input.strip(),
            {
                " " => "", "pi" => "π", "sqrt" => "2√", "root" => "√", "²" => "^2", "³" => "^3", "⁴" => "^4", "⁵" => "^5", "⁶" => "^6", "⁷" => "^7", "⁸" => "^8", "⁹" => "^9", "+-" => "-", "++" => "+", /(?<=\d|π|e|\))\(/ => "*(", /\)(?=\d|π|e|\()/ => ")*", /(?<=\d|\))π/ => "*π", /π(?=\d|\()/ => "π*", /(?<=\d|\))e/ => "*e", /e(?=\d|\()/ => "e*"
            }
        )
    end


    def self.is_operator?(input : Char)
        case input
            when '+', '-'
                0
            when '*', '/', '%'
                1
            when '√', '^'
                2
            else
                -1 
        end
    end


    def self.factorial(n : Int32)
        if n == 1 || n == 2
            1
        else
            self.factorial(n - 1) + self.factorial(n - 2)
        end
    end


end