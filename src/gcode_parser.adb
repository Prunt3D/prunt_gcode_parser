-----------------------------------------------------------------------------
--                                                                         --
--                   Part of the Prunt Motion Controller                   --
--                                                                         --
--            Copyright (C) 2024 Liam Powell (liam@prunt3d.com)            --
--                                                                         --
--  This program is free software: you can redistribute it and/or modify   --
--  it under the terms of the GNU General Public License as published by   --
--  the Free Software Foundation, either version 3 of the License, or      --
--  (at your option) any later version.                                    --
--                                                                         --
--  This program is distributed in the hope that it will be useful,        --
--  but WITHOUT ANY WARRANTY; without even the implied warranty of         --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          --
--  GNU General Public License for more details.                           --
--                                                                         --
--  You should have received a copy of the GNU General Public License      --
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.  --
--                                                                         --
-----------------------------------------------------------------------------

with Ada.Characters.Handling; use Ada.Characters.Handling;

package body Gcode_Parser is

   type Parameter_Kind is (Non_Existant_Kind, No_Value_Kind, Integer_Kind, Float_Kind);

   type Parameter_Integer is range 0 .. 999;

   type Parameter (Kind : Parameter_Kind := Non_Existant_Kind) is record
      Consumed : Boolean;
      case Kind is
         when Non_Existant_Kind =>
            null;
         when No_Value_Kind =>
            null;
         when Integer_Kind =>
            Integer_Value : Parameter_Integer;
         when Float_Kind =>
            Float_Value : Dimensionless;
      end case;
   end record;

   type Parameters_Index is new Character range 'A' .. 'Z';
   type Parameters_Array is array (Parameters_Index) of Parameter;

   function Make_Context (Initial_Position : Position; Initial_Feedrate : Velocity) return Context is
   begin
      return (Relative_Mode => False, Pos => Initial_Position, Feedrate => Initial_Feedrate);
   end Make_Context;

   procedure Parse_Line (Ctx : in out Context; Line : String; Comm : out Command) is
      Params : Parameters_Array := [others => (Kind => Non_Existant_Kind, Consumed => False)];
      I      : Positive         := Line'First;

      procedure Parse_Number (Param : Parameters_Index) is
         In_Decimal_Part : Boolean := False;
         Is_Negative     : Boolean := False;
         Is_First_Char   : Boolean := True;
         Decimal_Digits  : Natural := 0;
      begin
         Params (Param) := (Kind => No_Value_Kind, Consumed => False);

         loop
            I := I + 1;
            exit when I = Line'Last + 1 or else (Line (I) /= '.' and Line (I) /= '-' and not Is_Decimal_Digit (Line (I)));

            if Params (Param).Kind = No_Value_Kind then
               Params (Param) := (Kind => Integer_Kind, Integer_Value => 0, Consumed => False);
            end if;

            if Params (Param).Kind = Integer_Kind
               and then (Params (Param).Integer_Value >= 100 or Line (I) = '.')
            then
               Params (Param) :=
                  (Kind        => Float_Kind,
                  Float_Value => Dimensionless (Params (Param).Integer_Value),
                  Consumed    => False);
            end if;

            if Line (I) = '-' then
               if not Is_First_Char then
                  raise Bad_Line with "'-' only allowed as first character in number.";
               end if;
               Is_Negative := True;
            elsif Line (I) = '.' then
               if In_Decimal_Part then
                  raise Bad_Line with "Multiple decimal points in number.";
               end if;
               In_Decimal_Part := True;
            else
               if Params (Param).Kind = Integer_Kind then
                  Params (Param).Integer_Value :=
                     @ * 10 + Parameter_Integer (Character'Pos (Line (I)) - Character'Pos ('0'));
               else
                  if In_Decimal_Part then
                     Decimal_Digits             := @ + 1;
                     Params (Param).Float_Value :=
                        @ + Dimensionless (Character'Pos (Line (I)) - Character'Pos ('0')) / 10.0**Decimal_Digits;
                  else
                     Params (Param).Float_Value :=
                        @ * 10.0 + Dimensionless (Character'Pos (Line (I)) - Character'Pos ('0'));
                  end if;
               end if;
            end if;

            Is_First_Char := False;
         end loop;

         if Is_Negative then
            if Params (Param).Kind = No_Value_Kind then
               raise Bad_Line with "Got '-' with no following number.";
            elsif Params (Param).Kind = Integer_Kind then
               Params (Param) :=
                 (Kind => Float_Kind, Float_Value => -Dimensionless (Params (Param).Integer_Value), Consumed => False);
            elsif Params (Param).Kind = Float_Kind then
               Params (Param).Float_Value := -Params (Param).Float_Value;
            end if;
         end if;
      end Parse_Number;

      function Floatify_Or_Default (Param : Parameters_Index; Default : Dimensionless) return Dimensionless is
      begin
         if Params (Param).Consumed then
            raise Program_Error with "Parameter '" & Character (Param) & "' already consumed.";
         end if;
         Params (Param).Consumed := True;

         case Params (Param).Kind is
            when No_Value_Kind =>
               raise Bad_Line
                 with "Parameter '" & Character (Param) & "' has no value in command requiring value or omission.";
            when Non_Existant_Kind =>
               return Default;
            when Integer_Kind =>
               return Dimensionless (Params (Param).Integer_Value);
            when Float_Kind =>
               return Params (Param).Float_Value;
         end case;
      end Floatify_Or_Default;

      function Floatify_Or_Error (Param : Parameters_Index) return Dimensionless is
      begin
         if Params (Param).Consumed then
            raise Program_Error with "Parameter '" & Character (Param) & "' already consumed.";
         end if;
         Params (Param).Consumed := True;

         case Params (Param).Kind is
            when No_Value_Kind =>
               raise Bad_Line with "Parameter '" & Character (Param) & "' has no value in command requiring value.";
            when Non_Existant_Kind =>
               raise Bad_Line with "Parameter '" & Character (Param) & "' missing in command requiring value.";
            when Integer_Kind =>
               return Dimensionless (Params (Param).Integer_Value);
            when Float_Kind =>
               return Params (Param).Float_Value;
         end case;
      end Floatify_Or_Error;

      function Integer_Or_Default (Param : Parameters_Index; Default : Parameter_Integer) return Parameter_Integer is
      begin
         if Params (Param).Consumed then
            raise Program_Error with "Parameter '" & Character (Param) & "' already consumed.";
         end if;
         Params (Param).Consumed := True;

         case Params (Param).Kind is
            when No_Value_Kind =>
               raise Bad_Line
                 with "Parameter '" & Character (Param) & "' has no value in command requiring value or omission.";
            when Non_Existant_Kind =>
               return Default;
            when Integer_Kind =>
               return Params (Param).Integer_Value;
            when Float_Kind =>
               raise Bad_Line with "Parameter '" & Character (Param) & "' should be non-negative integer < 1000.";
         end case;
      end Integer_Or_Default;

      function Integer_Or_Error (Param : Parameters_Index) return Parameter_Integer is
      begin
         if Params (Param).Consumed then
            raise Program_Error with "Parameter '" & Character (Param) & "' already consumed.";
         end if;
         Params (Param).Consumed := True;

         case Params (Param).Kind is
            when No_Value_Kind =>
               raise Bad_Line with "Parameter '" & Character (Param) & "' has no value in command requiring value.";
            when Non_Existant_Kind =>
               raise Bad_Line with "Parameter '" & Character (Param) & "' missing in command requiring value.";
            when Integer_Kind =>
               return Params (Param).Integer_Value;
            when Float_Kind =>
               raise Bad_Line with "Parameter '" & Character (Param) & "' should be non-negative integer < 1000.";
         end case;
      end Integer_Or_Error;

      function No_Value_Or_False_Or_Error (Param : Parameters_Index) return Boolean is
      begin
         if Params (Param).Consumed then
            raise Program_Error with "Parameter '" & Character (Param) & "' already consumed.";
         end if;
         Params (Param).Consumed := True;

         case Params (Param).Kind is
            when No_Value_Kind =>
               return True;
            when Non_Existant_Kind =>
               return False;
            when Integer_Kind | Float_Kind =>
               raise Bad_Line with "Parameter '" & Character (Param) & "' not allowed to have a value here.";
         end case;
      end No_Value_Or_False_Or_Error;

   begin
      if Line'Length /= 0 then
         loop
            exit when Line (I) = ';';

            if Line (I) = ' ' then
               I := I + 1;
            else
               declare
                  Char : constant Character := To_Upper (Line (I));
               begin
                  if Parameters_Index'Base (Char) not in Parameters_Index then
                     if Is_Control (Char) or Character'Pos (Char) > 127 then
                        raise Bad_Line with "Expected parameter letter, got unprintable character.";
                     else
                        raise Bad_Line with "Expected parameter letter, got '" & Line (I) & "'.";
                     end if;
                  elsif Params (Parameters_Index (Char)).Kind /= Non_Existant_Kind then
                     raise Bad_Line with "Parameter letter '" & Char & "' encountered more than once on line.";
                  else
                     Parse_Number (Parameters_Index (Char));
                  end if;
               end;
            end if;

            exit when I = Line'Last + 1;
         end loop;
      end if;

      if Params ('G').Kind /= Non_Existant_Kind and Params ('M').Kind /= Non_Existant_Kind then
         raise Bad_Line with "Only one G or M parameter allowed per line.";
      end if;

      if Params ('G').Kind /= Non_Existant_Kind then
         Params ('G').Consumed := True;

         if Params ('G').Kind /= Integer_Kind then
            raise Bad_Line with "Bad G parameter format: " & Params ('G')'Image;
         end if;

         case Params ('G').Integer_Value is
            when 0 | 1 =>
               Comm := (Kind => Move_Kind, others => <>);
               if Ctx.Relative_Mode then
                  Comm.Pos (X_Axis) := Comm.Pos (X_Axis) + Floatify_Or_Default ('X', 0.0) * mm;
                  Comm.Pos (Y_Axis) := Comm.Pos (Y_Axis) + Floatify_Or_Default ('Y', 0.0) * mm;
                  Comm.Pos (Z_Axis) := Comm.Pos (Z_Axis) + Floatify_Or_Default ('Z', 0.0) * mm;
                  Comm.Pos (E_Axis) := Comm.Pos (E_Axis) + Floatify_Or_Default ('E', 0.0) * mm;
               else
                  Comm.Pos (X_Axis) := Floatify_Or_Default ('X', Ctx.Pos (X_Axis) / mm) * mm;
                  Comm.Pos (Y_Axis) := Floatify_Or_Default ('Y', Ctx.Pos (Y_Axis) / mm) * mm;
                  Comm.Pos (Z_Axis) := Floatify_Or_Default ('Z', Ctx.Pos (Z_Axis) / mm) * mm;
                  Comm.Pos (E_Axis) := Floatify_Or_Default ('E', Ctx.Pos (E_Axis) / mm) * mm;
               end if;
               Comm.Feedrate := Floatify_Or_Default ('F', Ctx.Feedrate / (mm / min)) * mm / min;
            when 4 =>
               Comm := (Kind => Dwell_Kind, Dwell_Time => Floatify_Or_Error ('S') * s);
            when 21 =>
               Comm := (Kind => None_Kind);
            when 28 =>
               Comm :=
                 (Kind       => Home_Kind,
                  Axes       =>
                    [E_Axis => No_Value_Or_False_Or_Error ('E'),
                    X_Axis  => No_Value_Or_False_Or_Error ('X'),
                    Y_Axis  => No_Value_Or_False_Or_Error ('Y'),
                    Z_Axis  => No_Value_Or_False_Or_Error ('Z')],
                  Pos_Before => Ctx.Pos);
            when 90 =>
               Ctx.Relative_Mode := False;
               Comm := (Kind => None_Kind);
            when 91 =>
               Ctx.Relative_Mode := True;
               Comm := (Kind => None_Kind);
            when 92 =>
               Comm :=
                 (Kind    => Reset_Position_Kind,
                  New_Pos => (Ctx.Pos with delta E_Axis => Floatify_Or_Error ('E')));
            when others =>
               raise Bad_Line with "Unknown G code: " & Params ('G').Integer_Value'Image;
         end case;
      elsif Params ('M').Kind /= Non_Existant_Kind then
         Params ('M').Consumed := True;

         if Params ('M').Kind /= Integer_Kind then
            raise Bad_Line with "Bad M parameter format: " & Params ('M')'Image;
         end if;

         case Params ('M').Integer_Value is
            when 0 | 1 =>
               Comm := (Kind => Pause_Kind);
            when 17 =>
               Comm :=
                 (Kind => Enable_Steppers_Kind,
                  Axes =>
                    [E_Axis => No_Value_Or_False_Or_Error ('E'),
                    X_Axis  => No_Value_Or_False_Or_Error ('X'),
                    Y_Axis  => No_Value_Or_False_Or_Error ('Y'),
                    Z_Axis  => No_Value_Or_False_Or_Error ('Z')]);
            when 18 | 84 =>
               Comm :=
                 (Kind => Disable_Steppers_Kind,
                  Axes =>
                    [E_Axis => No_Value_Or_False_Or_Error ('E'),
                    X_Axis  => No_Value_Or_False_Or_Error ('X'),
                    Y_Axis  => No_Value_Or_False_Or_Error ('Y'),
                    Z_Axis  => No_Value_Or_False_Or_Error ('Z')]);
            when 104 =>
               Comm := (Kind => Set_Hotend_Temperature_Kind, Target_Temperature => Floatify_Or_Error ('S') * celcius);
            when 106 =>
               Comm :=
                 (Kind      => Set_Fan_Speed_Kind,
                  Fan_Speed => Dimensionless'Min (1.0, Dimensionless'Max (0.0, Floatify_Or_Error ('S') / 255.0)));
            when 107 =>
               Comm := (Kind => Set_Fan_Speed_Kind, Fan_Speed => 0.0);
            when 109 =>
               Comm := (Kind => Wait_Hotend_Temperature_Kind, Target_Temperature => Floatify_Or_Error ('S') * celcius);
            when 140 =>
               Comm := (Kind => Set_Bed_Temperature_Kind, Target_Temperature => Floatify_Or_Error ('S') * celcius);
            when 141 =>
               Comm := (Kind => Set_Chamber_Temperature_Kind, Target_Temperature => Floatify_Or_Error ('S') * celcius);
            when 190 =>
               Comm := (Kind => Wait_Bed_Temperature_Kind, Target_Temperature => Floatify_Or_Error ('S') * celcius);
            when 191 =>
               Comm :=
                 (Kind => Wait_Chamber_Temperature_Kind, Target_Temperature => Floatify_Or_Error ('S') * celcius);
            when others =>
               raise Bad_Line with "Unknown M code: " & Params ('M').Integer_Value'Image;
         end case;
      else
         Comm := (Kind => None_Kind);
      end if;

      for I in Params'Range loop
         if not Params (I).Consumed and Params (I).Kind /= Non_Existant_Kind then
            raise Bad_Line with "Parameter '" & Character (I) & "' not valid for command on line.";
         end if;
      end loop;

      if Comm.Kind = Move_Kind then
         Comm.Old_Pos := Ctx.Pos;
         Ctx.Pos      := Comm.Pos;

         if Params ('G').Kind = Integer_Kind and then Params ('G').Integer_Value in 0 .. 1 then
            Ctx.Feedrate := Comm.Feedrate;
         end if;
      end if;

   end Parse_Line;

   procedure Reset_Position (Ctx : in out Context; Pos : Position) is
   begin
      Ctx.Pos := Pos;
   end Reset_Position;

end Gcode_Parser;
