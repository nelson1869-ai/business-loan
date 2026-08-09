# WorkManager uses Room-generated *Database_Impl classes reflectively at startup.
# R8 must keep their no-arg constructors or the app crashes with
# NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init> [].
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keepclassmembers class * extends androidx.room.RoomDatabase { <init>(); }
-keep class * extends androidx.work.** { <init>(); }
