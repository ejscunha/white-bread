defmodule WhiteBread.Context do
  alias WhiteBread.Context.StepMacroHelpers

  @steps_to_macro [:given_, :when_, :then_, :and_, :but_]

  @doc false
  defmacro __using__(_opts) do
    quote do
      import WhiteBread.Context
      import ExUnit.Assertions

      @string_steps HashDict.new

      # List of tuples {regex, function}
      @regex_steps []

      @sub_context_modules []

      @scenario_state_definied false
      @scenario_finalize_defined false
      @feature_state_definied false

      @before_compile WhiteBread.Context
    end
  end

  @doc false
  defmacro __before_compile__(_env) do

    quote do
      def execute_step(step, state) do
        {get_string_steps, get_regex_steps}
        |> WhiteBread.Context.StepExecutor.execute_step(step, state)
      end

      def get_string_steps do
        :get_string_steps
          |> apply_to_sub_modules
          |> Enum.into(@string_steps)
      end

      def get_regex_steps do
        :get_regex_steps
          |> apply_to_sub_modules
          |> Enum.into(@regex_steps)
      end

      unless @feature_state_definied do
        def feature_state() do
          # Always default to an empty map
          %{}
        end
      end

      unless @scenario_state_definied do
        def starting_state(state) do
          state
        end
      end

      unless @scenario_finalize_defined do
        def finalize(_ignored_state), do: nil
      end

      defp apply_to_sub_modules(function) do
        @sub_context_modules
        |> Enum.map(fn(sub_module) -> apply(sub_module, function, []) end)
        |> Enum.flat_map(fn(x) -> x end)
      end

    end
  end

  for step <- @steps_to_macro do

    defmacro unquote(step)(step_text, do: block) do
      StepMacroHelpers.define_block_step(step_text, block)
    end

    defmacro unquote(step)(step_text, step_function) do
      StepMacroHelpers.define_function_step(step_text, step_function)
    end
  end

  defmacro feature_starting_state(function) do
    quote do
      @feature_state_definied true
      def feature_state() do
        unquote(function).()
      end
    end
  end

  defmacro scenario_starting_state(function) do
    quote do
      @scenario_state_definied true
      def starting_state(state) do
        unquote(function).(state)
      end
    end
  end

  defmacro scenario_finalize(function) do
    quote do
      @scenario_finalize_defined true
      def finalize(state) do
        case is_function(unquote(function), 1) do
          true  -> unquote(function).(state)
          false -> unquote(function).()
        end
      end
    end
  end

  defmacro subcontext(context_module) do
    quote do
      @sub_context_modules [unquote(context_module) | @sub_context_modules]
    end
  end


end
