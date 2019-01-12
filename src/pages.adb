--    Copyright 2019 Bartek thindil Jasicki
--
--    This file is part of YASS.
--
--    YASS is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    YASS is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    You should have received a copy of the GNU General Public License
--    along with YASS.  If not, see <http://www.gnu.org/licenses/>.

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Characters.Latin_1; use Ada.Characters.Latin_1;
with Ada.Strings.UTF_Encoding.Strings; use Ada.Strings.UTF_Encoding.Strings;
with Ada.Directories; use Ada.Directories;
with Interfaces.C; use Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with Layouts; use Layouts;
with Config; use Config;

package body Pages is

   subtype size_t is unsigned_long;

   function cmark_markdown_to_html(text: Interfaces.C.Strings.chars_ptr;
      len: size_t; options: int) return Interfaces.C.Strings.chars_ptr;
   pragma Import(C, cmark_markdown_to_html, "cmark_markdown_to_html");

   procedure CreatePage(FileName, Directory: String) is
      Layout, Data, Contents: Unbounded_String;
      PageFile: File_Type;
      StartIndex: Natural;
   begin
      Open(PageFile, In_File, FileName);
      while not End_Of_File(PageFile) loop
         Data := To_Unbounded_String(Get_Line(PageFile));
         if Length(Data) > 0 then
            if Slice(Data, 1, 3) = "-- " then
               if Index(Data, "layout:", 1) > 0 then
                  Data := Unbounded_Slice(Data, 12, Length(Data));
                  Layout :=
                    LoadLayout
                      (Directory & "/" &
                       To_String(YassConfig.LayoutsDirectory) & "/" &
                       To_String(Data) & ".html");
               end if;
            else
               Append(Contents, Data);
               Append(Contents, LF);
            end if;
         end if;
      end loop;
      Close(PageFile);
      Contents :=
        To_Unbounded_String
          (Value
             (cmark_markdown_to_html
                (New_String(Encode(To_String(Contents))),
                 size_t(Length(Contents)), 0)));
      StartIndex := Index(Layout, "{%Contents%}", 1);
      Replace_Slice(Layout, StartIndex, StartIndex + 12, To_String(Contents));
      for I in SiteTags.Iterate loop
         loop
            StartIndex := Index(Layout, "{%" & Tags_Container.Key(I) & "%}");
            exit when StartIndex = 0;
            Replace_Slice
              (Layout, StartIndex,
               StartIndex + 3 + Tags_Container.Key(I)'Length, SiteTags(I));
         end loop;
      end loop;
      Create
        (PageFile, Append_File,
         Directory & "/" & To_String(YassConfig.OutputDirectory) & "/" &
         Base_Name(FileName) & ".html");
      Put(PageFile, To_String(Layout));
      Close(PageFile);
   end CreatePage;

end Pages;
