with Physical_Types; use Physical_Types;

package Gcode_Parser is

   type Command_Kind is
     (None_Kind,
      Pause_Kind,
      Move_Kind,
      Reset_Position_Kind,
      Dwell_Kind,
      Home_Kind,
      Enable_Steppers_Kind,
      Disable_Steppers_Kind,
      Set_Hotend_Temperature_Kind,
      Wait_Hotend_Temperature_Kind,
      Set_Bed_Temperature_Kind,
      Wait_Bed_Temperature_Kind,
      Set_Chamber_Temperature_Kind,
      Wait_Chamber_Temperature_Kind,
      Set_Fan_Speed_Kind);

   type Axes_Set is array (Axis_Name) of Boolean;

   type Command (Kind : Command_Kind := None_Kind) is record
      case Kind is
         when None_Kind | Pause_Kind =>
            null;
         when Move_Kind =>
            Old_Pos  : Position;
            Pos      : Position;
            Feedrate : Velocity;
         when Reset_Position_Kind =>
            New_Pos : Position;
         when Dwell_Kind =>
            Dwell_Time : Time;
         when Home_Kind | Enable_Steppers_Kind | Disable_Steppers_Kind =>
            Axes : Axes_Set;
            case Kind is
               when Home_Kind =>
                  Pos_Before : Position;
               when others =>
                  null;
            end case;
         when Set_Hotend_Temperature_Kind
           | Wait_Hotend_Temperature_Kind
           | Set_Bed_Temperature_Kind
           | Wait_Bed_Temperature_Kind
           | Set_Chamber_Temperature_Kind
           | Wait_Chamber_Temperature_Kind =>
            Target_Temperature : Temperature;
         when Set_Fan_Speed_Kind =>
            Fan_Speed : PWM_Scale;
      end case;
   end record;

   type Context is private;

   function Make_Context (Initial_Position : Position; Initial_Feedrate : Velocity) return Context;

   procedure Parse_Line (Ctx : in out Context; Line : String; Comm : out Command);
   procedure Reset_Position (Ctx : in out Context; Pos : Position);

   Bad_Line : exception;

private

   type Context is record
      Relative_Mode : Boolean;
      Pos           : Position;
      Feedrate      : Velocity;
   end record;

end Gcode_Parser;
