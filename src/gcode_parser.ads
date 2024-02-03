with Physical_Types; use Physical_Types;

package Gcode_Parser is

   type Command_Kind is
     (None_Kind,
      Move_Kind,
      Dwell_Kind,
      Home_Kind,
      Enable_Steppers_Kind,
      Disable_Steppers_Kind,
      Set_Hotend_Temperature_Kind,
      Wait_Hotend_Temperature_Kind,
      Set_Bed_Temperature_Kind,
      Wait_Bed_Temperature_Kind,
      Set_Fan_Speed_Kind);

   type Axes_Set is array (Axis_Name) of Boolean;

   type Command (Kind : Command_Kind := None_Kind) is record
      case Kind is
         when None_Kind =>
            null;
         when Move_Kind =>
            Pos      : Position;
            Feedrate : Velocity;
         when Dwell_Kind =>
            Dwell_Time : Time;
         when Home_Kind | Enable_Steppers_Kind | Disable_Steppers_Kind =>
            Axes : Axes_Set;
         when Set_Hotend_Temperature_Kind
           | Wait_Hotend_Temperature_Kind
           | Set_Bed_Temperature_Kind
           | Wait_Bed_Temperature_Kind =>
            Target_Temperature : Temperature;
         when Set_Fan_Speed_Kind =>
            null;  --  TODO
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
