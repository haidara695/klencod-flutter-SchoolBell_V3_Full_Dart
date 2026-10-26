import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

const appName='الجرس المدرسي الذكي V3';
const daysAr=['الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
final noticePlugin=FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const init=InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
  try { await noticePlugin.initialize(init); } catch (_) {}
  runApp(const SchoolBellApp());
}
class SchoolBellApp extends StatelessWidget {
  const SchoolBellApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(
    title:appName, debugShowCheckedModeBanner:false,
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff1746a2)),
      scaffoldBackgroundColor:const Color(0xfff3f6fc)),
    home:const HomePage());
}
class Bell {
  String id,title,subject,grade,section,soundPath;
  int hour,minute;
  List<int> days;
  bool enabled;
  Bell({required this.id,required this.title,required this.subject,required this.grade,required this.section,
    required this.hour,required this.minute,required this.days,this.enabled=true,this.soundPath=''});
  Map<String,dynamic> toJson()=>{'id':id,'title':title,'subject':subject,'grade':grade,'section':section,
    'hour':hour,'minute':minute,'days':days,'enabled':enabled,'soundPath':soundPath};
  factory Bell.fromJson(Map<String,dynamic> j)=>Bell(
    id:'${j['id']??DateTime.now().microsecondsSinceEpoch}',title:'${j['title']??'الحصة'}',
    subject:'${j['subject']??''}',grade:'${j['grade']??''}',section:'${j['section']??''}',
    hour:(j['hour'] as num?)?.toInt()??8,minute:(j['minute'] as num?)?.toInt()??0,
    days:((j['days'] as List?)??[0,1,2,3,4]).map((x)=>(x as num).toInt()).toList(),
    enabled:j['enabled']!=false,soundPath:'${j['soundPath']??''}');
}
class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  List<Bell> bells=[]; bool enabled=true; int duration=8; Timer? timer;
  DateTime? nextAt; Bell? nextBell; Duration left=Duration.zero;
  final player=AudioPlayer();
  static const bellChannel=MethodChannel('com.haidara.schoolbell/alarms');
  @override void initState(){super.initState();_load();timer=Timer.periodic(const Duration(seconds:1),(_)=>_countdown());Permission.notification.request();}
  List<Bell> sample()=>[
    Bell(id:'1',title:'الحصة الأولى',subject:'الحاسوب',grade:'الخامس',section:'أ',hour:8,minute:0,days:[0,1,2,3,4]),
    Bell(id:'2',title:'الحصة الثانية',subject:'الحاسوب',grade:'السابع',section:'أ',hour:8,minute:45,days:[0,1,2,3,4]),
    Bell(id:'3',title:'الفسحة',subject:'استراحة',grade:'كل الصفوف',section:'',hour:10,minute:15,days:[0,1,2,3,4])];
  Future<void> _load() async {
    final p=await SharedPreferences.getInstance(); final raw=p.getString('bells_v3');
    try { bells=raw==null?sample():(jsonDecode(raw) as List).map((e)=>Bell.fromJson(Map<String,dynamic>.from(e))).toList(); }
    catch(_){bells=sample();}
    enabled=p.getBool('enabled')??true;duration=p.getInt('duration')??8;
    if(mounted)setState((){});_countdown();_schedule();
  }
  Future<void> _save() async {final p=await SharedPreferences.getInstance();
    await p.setString('bells_v3',jsonEncode(bells.map((e)=>e.toJson()).toList()));
    await p.setBool('enabled',enabled);await p.setInt('duration',duration);await _schedule();_countdown();}
  DateTime? occurrence(Bell b,DateTime now){
    if(!b.enabled||b.days.isEmpty)return null;
    for(int i=0;i<=7;i++){final d=DateTime(now.year,now.month,now.day+i,b.hour,b.minute);
      if(b.days.contains(d.weekday-1)&&d.isAfter(now))return d;}return null;
  }
  void _countdown(){if(!mounted)return; if(!enabled){setState(()=>{nextAt=null,nextBell=null,left=Duration.zero});return;}
    final now=DateTime.now(); Bell? best;DateTime? at;
    for(final b in bells){final d=occurrence(b,now);if(d!=null&&(at==null||d.isBefore(at))){best=b;at=d;}}
    setState((){nextBell=best;nextAt=at;left=at==null?Duration.zero:at.difference(now);});}
  Future<void> _schedule() async {
    try {
      await bellChannel.invokeMethod('schedule', {
        'enabled': enabled,
        'duration': duration,
        'bells': bells.map((b)=>b.toJson()).toList(),
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('تعذر ضبط أجراس الخلفية: $e')));
    }
  }
  Future<void> _requestExactAlarm() async {
    try {await bellChannel.invokeMethod('requestExactAlarm');}
    catch (_) {}
  }
  String clock(Bell b)=>'${b.hour.toString().padLeft(2,'0')}:${b.minute.toString().padLeft(2,'0')}';
  String countdown(Duration d)=>d.inHours>0?'${d.inHours.toString().padLeft(2,'0')}:${d.inMinutes.remainder(60).toString().padLeft(2,'0')}:${d.inSeconds.remainder(60).toString().padLeft(2,'0')}':'${d.inMinutes.remainder(60).toString().padLeft(2,'0')}:${d.inSeconds.remainder(60).toString().padLeft(2,'0')}';
  Future<void> edit([Bell? old]) async {final b=await showModalBottomSheet<Bell>(context:context,isScrollControlled:true,
    backgroundColor:Colors.transparent,builder:(_)=>Editor(old:old));
    if(b!=null){setState((){final i=bells.indexWhere((x)=>x.id==b.id);if(i<0)bells.add(b);else bells[i]=b;
      bells.sort((a,b)=>(a.hour*60+a.minute).compareTo(b.hour*60+b.minute));});await _save();}}
  Future<void> backup() async {final dir=await getTemporaryDirectory();final f=File('${dir.path}/school_bell_v3.json');
    await f.writeAsString(jsonEncode({'version':3,'enabled':enabled,'duration':duration,'bells':bells.map((b)=>b.toJson()).toList()}));
    await Share.shareXFiles([XFile(f.path)],text:'نسخة احتياطية للجرس المدرسي V3');}
  Future<void> restore() async {final r=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['json'],withData:true);
    if(r==null)return;try{final f=r.files.single;final s=f.bytes!=null?utf8.decode(f.bytes!):await File(f.path!).readAsString();
      final j=jsonDecode(s) as Map<String,dynamic>;setState((){bells=(j['bells'] as List).map((e)=>Bell.fromJson(Map<String,dynamic>.from(e))).toList();
      enabled=j['enabled']!=false;duration=(j['duration'] as num?)?.toInt()??8;});await _save();
    }catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ملف النسخة الاحتياطية غير صالح')));}}
  Future<void> test(Bell b) async {try{if(b.soundPath.isNotEmpty&&File(b.soundPath).existsSync()){await player.stop();await player.play(DeviceFileSource(b.soundPath));}
    else{await SystemSound.play(SystemSoundType.alert);}}catch(_){await SystemSound.play(SystemSoundType.alert);}}
  @override void dispose(){timer?.cancel();player.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(
    appBar:AppBar(backgroundColor:const Color(0xff1746a2),foregroundColor:Colors.white,title:const Text(appName,style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
      actions:[IconButton(onPressed:backup,icon:const Icon(Icons.ios_share)),PopupMenuButton<String>(onSelected:(v){if(v=='restore')restore();else showAboutDialog(context:context,applicationName:appName,applicationVersion:'3.0');},
        itemBuilder:(_)=>const [PopupMenuItem(value:'restore',child:Text('استيراد نسخة')),PopupMenuItem(value:'about',child:Text('حول التطبيق'))])]),
    floatingActionButton:FloatingActionButton.extended(onPressed:()=>test(bells.isEmpty?Bell(id:'x',title:'اختبار',subject:'',grade:'',section:'',hour:8,minute:0,days:[0]):bells.first),icon:const Icon(Icons.volume_up),label:const Text('اختبار الصوت')),
    body:ListView(padding:const EdgeInsets.all(15),children:[
      Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xff1746a2),Color(0xff3679e6)]),borderRadius:BorderRadius.circular(25)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[const Expanded(child:Text('العد التنازلي للجرس القادم',style:TextStyle(color:Colors.white70))),
            Switch(value:enabled,activeColor:Colors.white,onChanged:(v)async{setState(()=>enabled=v);await _save();})]),
          Text(!enabled?'متوقف':nextAt==null?'--:--':countdown(left),style:const TextStyle(color:Colors.white,fontSize:42,fontWeight:FontWeight.w900)),
          Text(nextBell==null?'لا توجد حصة قادمة': '${nextBell!.title} • ${clock(nextBell!)}',style:const TextStyle(color:Colors.white,fontSize:16)),
          const SizedBox(height:8),Text('اليوم: ${daysAr[DateTime.now().weekday-1]}',style:const TextStyle(color:Colors.white70))])),
      const SizedBox(height:17),Row(children:[const Expanded(child:Text('جدول الأجراس',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900))),
        FilledButton.icon(onPressed:()=>edit(),icon:const Icon(Icons.add),label:const Text('إضافة'))]),
      if(bells.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(22),child:Text('لا توجد مواعيد. اضغط إضافة.'))),
      ...bells.map((b)=>Card(margin:const EdgeInsets.symmetric(vertical:6),child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[
        const CircleAvatar(backgroundColor:Color(0xffe8efff),child:Icon(Icons.notifications_active,color:Color(0xff1746a2))),
        const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(b.title,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
          Text('${b.subject} • ${b.grade} ${b.section}',style:const TextStyle(color:Colors.black54,fontSize:12)),
          Text('${clock(b)}  |  ${b.days.map((d)=>daysAr[d]).join('، ')}',style:const TextStyle(color:Color(0xff1746a2),fontWeight:FontWeight.bold))])),
        Column(children:[Switch(value:b.enabled,onChanged:(v)async{setState(()=>b.enabled=v);await _save();}),
          PopupMenuButton<String>(onSelected:(v){if(v=='edit')edit(b);if(v=='test')test(b);if(v=='delete')showDialog(context:context,builder:(c)=>AlertDialog(title:const Text('حذف الموعد؟'),
            actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إلغاء')),TextButton(onPressed:()async{Navigator.pop(c);setState(()=>bells.removeWhere((x)=>x.id==b.id));await _save();},child:const Text('حذف'))]));},
            itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('تعديل')),PopupMenuItem(value:'test',child:Text('اختبار')),PopupMenuItem(value:'delete',child:Text('حذف'))])])]))),
      Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('إعدادات عامة',style:TextStyle(fontWeight:FontWeight.bold,fontSize:17)),
        Row(children:[const Expanded(child:Text('مدة الجرس (إعداد محفوظ)')),Text('$duration ثانية')]),
        Slider(value:duration.toDouble(),min:3,max:30,divisions:9,onChanged:(v)=>setState(()=>duration=v.round()),onChangeEnd:(_)=>_save()),
        OutlinedButton.icon(onPressed:_requestExactAlarm,icon:const Icon(Icons.alarm),label:const Text('السماح بالأجراس الدقيقة في الخلفية')),
        const Text('تطوير أ. محمد حيدره • للتواصل: 785068859',style:TextStyle(color:Colors.black54,fontSize:12))]))),
      const SizedBox(height:65)
    ])));
}
class Editor extends StatefulWidget {final Bell? old;const Editor({super.key,this.old});@override State<Editor> createState()=>_EditorState();}
class _EditorState extends State<Editor>{
  late TextEditingController title,subject,grade,section;late TimeOfDay time;late Set<int> days;late bool enabled;String sound='';
  @override void initState(){super.initState();final b=widget.old;title=TextEditingController(text:b?.title??'الحصة الجديدة');
    subject=TextEditingController(text:b?.subject??'');grade=TextEditingController(text:b?.grade??'');section=TextEditingController(text:b?.section??'');
    time=TimeOfDay(hour:b?.hour??8,minute:b?.minute??0);days=(b?.days??[0,1,2,3,4]).toSet();enabled=b?.enabled??true;sound=b?.soundPath??'';}
  @override void dispose(){title.dispose();subject.dispose();grade.dispose();section.dispose();super.dispose();}
  Widget field(TextEditingController c,String label,IconData icon)=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:TextField(controller:c,decoration:InputDecoration(labelText:label,prefixIcon:Icon(icon),
    filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14)))));
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Container(
    padding:EdgeInsets.fromLTRB(18,18,18,MediaQuery.of(context).viewInsets.bottom+18),
    decoration:const BoxDecoration(color:Color(0xfff3f6fc),borderRadius:BorderRadius.vertical(top:Radius.circular(26))),
    child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(widget.old==null?'إضافة موعد':'تعديل موعد',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
      field(title,'اسم الموعد *',Icons.notifications),field(subject,'المادة',Icons.menu_book),
      Row(children:[Expanded(child:field(grade,'الصف',Icons.school)),const SizedBox(width:8),Expanded(child:field(section,'الشعبة',Icons.groups))]),
      Card(child:ListTile(leading:const Icon(Icons.access_time),title:const Text('وقت الجرس'),subtitle:Text(time.format(context)),onTap:()async{final t=await showTimePicker(context:context,initialTime:time);if(t!=null)setState(()=>time=t);})),
      const Text('أيام التكرار',style:TextStyle(fontWeight:FontWeight.bold)),
      Wrap(spacing:5,children:List.generate(7,(i)=>FilterChip(label:Text(daysAr[i]),selected:days.contains(i),onSelected:(v)=>setState(()=>v?days.add(i):days.remove(i))))),
      SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('تفعيل الموعد'),value:enabled,onChanged:(v)=>setState(()=>enabled=v)),
      Card(child:ListTile(leading:const Icon(Icons.music_note),title:const Text('اختيار ملف صوت'),subtitle:Text(sound.isEmpty?'صوت تنبيه النظام':sound.split('/').last),onTap:()async{
        final r=await FilePicker.platform.pickFiles(type:FileType.audio);if(r!=null&&r.files.single.path!=null){final picked=File(r.files.single.path!);final dir=await getApplicationDocumentsDirectory();final copied=await picked.copy('${dir.path}/bell_${DateTime.now().microsecondsSinceEpoch}.${picked.path.split('.').last}');if(mounted)setState(()=>sound=copied.path);}})),
      const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:(){
        if(title.text.trim().isEmpty||days.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('اكتب اسم الموعد واختر يومًا')));return;}
        final b=widget.old;Navigator.pop(context,Bell(id:b?.id??DateTime.now().microsecondsSinceEpoch.toString(),title:title.text.trim(),
          subject:subject.text.trim(),grade:grade.text.trim(),section:section.text.trim(),hour:time.hour,minute:time.minute,days:days.toList()..sort(),enabled:enabled,soundPath:sound));
      },icon:const Icon(Icons.save),label:const Text('حفظ الموعد')))
    ]))));
}