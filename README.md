# Godot Icon

**Godot Icon** is tool for replacing godot Windows icon.
It simplifies current workflow as it does not need
any external tools other than **Godot** itself and can be
used on any operating system.

It consists of two scripts: one for generating user
customized icon from series of png images and second
for replacing default icon in the .exe file.

[If you need GUI version of this tool, you can find it in Godot Asset Library](https://godotengine.org/asset-library/asset/1554) or on [GitHub](https://github.com/pkowal1982/godoticonplugin) 

![**Godot Icon** will work with Godot templates which were compiled with icon produced by **Godot Icon**. For now it means Godot 4 alpha 5.](https://raw.githubusercontent.com/pkowal1982/godoticon/3.x/image/disclaimer.png)

Approach with rcedit is cumbersome and does not work
with projects which embed pck into executable. It's
because the size of default icon and customized one
almost always differ. After replacement **Godot** cannot
find the embedded pck and shows an error.
There's also need to create the icon, probably using magick.

**Godot Icon** fixes above issues by creating icons
which are always the same size in terms of disk size.
It is posible because produced icons are not compressed.
As these custom icons are uncompressed, the size of
unpacked executable grows about 200 kB. Typically
it should not be a problem because games are almost
always distributed in some compressed form.

Using Godot Icon is simple. Download two scripts
(no need to download the whole project):  
[CreateIcon.gd for Godot 4.x](https://github.com/pkowal1982/godoticon/blob/master/CreateIcon.gd)  
[CreateIcon.gd for Godot 3.x](https://github.com/pkowal1982/godoticon/blob/3.x/CreateIcon.gd)  
and  
[ReplaceIcon.gd for Godot 4.x](https://github.com/pkowal1982/godoticon/blob/master/ReplaceIcon.gd)  
[ReplaceIcon.gd for Godot 3.x](https://github.com/pkowal1982/godoticon/blob/3.x/ReplaceIcon.gd)

## How to use it

Workflow is very simple. If you have only one png prepared
run first script in command line like this:

```
godot -s CreateIcon.gd customized.ico customized.png
```

Call it like this when you have six required resolutions:

```
godot -s CreateIcon.gd customized.ico customized1.png customized2.png ...
```

Then use created icon with your exported project:

```
godot -s ReplaceIcon.gd customized.ico MyProject.exe
```

When you provide multiple files to icon creator remember
that they should be in sizes: 16x16, 32x32, 48x48, 64x64,
128x128 and 256x256 pixels.

![Remember that Windows caches icons so you probably need to refresh this cache. Hacky way is to rename the executable after icon replacement.](https://raw.githubusercontent.com/pkowal1982/godoticon/3.x/image/warning.png)

Refreshing icon cache in Windows 10:

```
ie4uinit.exe -show
```

and in other versions:

```
ie4uinit.exe -ClearIconCache
```

