with Ada.Text_IO; use Ada.Text_IO;

procedure Actors is

   type Actor_ID is range 1..10;

   task type Actor (ID: Actor_ID);
   type Actor_Access is access all Actor;

   protected type SyncData is
      entry SelectActor (ID: Actor_ID);
      entry ResetSync (ID: Actor_ID);
      entry WaitUntilReady;
   private
      InUse: Boolean := True;
   end SyncData;
   type SyncData_Access is access all SyncData;

   task type SharedResource (My_SyncData: SyncData_Access) is
      entry PrepareWrite (ID: in Actor_ID; Write: out SyncData_Access);
      entry PrepareRead(ID: in Actor_ID; Read: out SyncData_Access);
   end SharedResource;

   SyncData1    : aliased SyncData;
   SharedResource1: SharedResource (SyncData1'Access);

   protected body SyncData is
      entry SelectActor (ID: Actor_ID)
        when InUse is
      begin
       InUse := False;
       Put_Line (Actor_ID'Image (ID) & ": SyncData");
      end;

      entry ResetSync (ID: Actor_ID)
        when not InUse is
      begin
         InUse := True;
         Put_Line (Actor_ID'Image (ID) & ": reset SyncData");
      end;

      entry WaitUntilReady
        when InUse is
      begin
         null;
      end;
   end SyncData;

   task body SharedResource is
   begin
      loop
         My_SyncData.WaitUntilReady;
         select
            when PrepareRead'count = 0 =>
             accept PrepareWrite (ID: in Actor_ID; Write: out SyncData_Access)
             do
               My_SyncData.SelectActor (ID);
               Write := My_SyncData;
             end PrepareWrite;
            or
            accept PrepareRead (ID: in Actor_ID; Read: out SyncData_Access) do
               My_SyncData.SelectActor (ID);
               Read := My_SyncData;
            end PrepareRead;
         or
            terminate;
         end select;
      end loop;
   end;

   task body Actor is
      SD : SyncData_Access;
   begin
      SharedResource1.PrepareWrite (ID, SD);
      Put_Line (Actor_ID'Image (ID) & " preparing write");
      delay 1.0;
      SD.ResetSync (ID);
      delay 2.5;
      loop
         select
            SharedResource1.PrepareRead (ID, SD);
            exit;
         or
            delay 1.5;
            Put_Line (Actor_ID'Image (ID) & " preparing read");
         end select;
      end loop;
      delay 2.0;
      Put_Line (Actor_ID'Image (ID) & " done!");
      SD.ResetSync (ID);
   end;

   NewActor: Actor_Access;

begin
   for Index in Actor_ID'Range loop
     -- can't just "new" things up, so assigning the result to something
      NewActor := new Actor (Index);
      delay 2.0;
   end loop;
end Actors;
