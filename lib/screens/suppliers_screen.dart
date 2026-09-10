import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/supplier.dart';
import '../providers/poultry_provider.dart';
import '../widgets/app_shell.dart';
import '../services/expense_category_config.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});
  @override State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _search = TextEditingController();
  @override void dispose(){_search.dispose();super.dispose();}
  String _initials(String name){final p=name.trim().split(RegExp(r'\\s+')).where((x)=>x.isNotEmpty).toList(); if(p.isEmpty)return 'S'; return (p.first[0]+(p.length>1?p.last[0]:'')).toUpperCase();}
  @override Widget build(BuildContext context){
    return Consumer<PoultryProvider>(builder:(context,p,_){
      final q=_search.text.trim().toLowerCase();
      final items=p.suppliers.where((s)=>q.isEmpty||s.fullName.toLowerCase().contains(q)||s.contactNumber.toLowerCase().contains(q)||s.businessAddress.toLowerCase().contains(q)).toList();
      return ListView(padding:const EdgeInsets.fromLTRB(14,8,14,28),children:[
        Row(children:[Expanded(child:TextField(controller:_search,onChanged:(_)=>setState((){}),decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'Search suppliers',border:OutlineInputBorder(borderRadius:BorderRadius.circular(12))))),const SizedBox(width:10),if(p.isAdmin)FilledButton.icon(onPressed:()=>_edit(context,p),icon:const Icon(Icons.add),label:const Text('Add Supplier'))]),
        const SizedBox(height:14),
        if(items.isEmpty)const AppCard(child:Padding(padding:EdgeInsets.all(22),child:Center(child:Text('No suppliers found.',style:TextStyle(color:Color(0xFF75867D)))))),
        ...items.map((s)=>_supplierCard(context,p,s)),
      ]);
    });
  }
  Widget _supplierCard(BuildContext context,PoultryProvider p,Supplier s)=>Card(margin:const EdgeInsets.only(bottom:10),elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),side:const BorderSide(color:Color(0xFFE1EAE5))),child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:8),leading:CircleAvatar(radius:25,backgroundColor:const Color(0xFFE6F5ED),child:Text(_initials(s.fullName),style:const TextStyle(color:Color(0xFF087A4F),fontWeight:FontWeight.w900))),title:Text(s.fullName,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Padding(padding:const EdgeInsets.only(top:5),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[if(s.contactNumber.isNotEmpty)Text(s.contactNumber),if(s.businessAddress.isNotEmpty)Text(s.businessAddress,maxLines:2,overflow:TextOverflow.ellipsis),if(s.category.isNotEmpty)Text(s.category,style:const TextStyle(color:Color(0xFF087A4F),fontWeight:FontWeight.w600))])),trailing:p.isAdmin?IconButton(tooltip:'Edit supplier',onPressed:()=>_edit(context,p,s),icon:const Icon(Icons.edit_outlined)):null));
  Future<void> _edit(BuildContext context,PoultryProvider p,[Supplier? existing])async{final name=TextEditingController(text:existing?.fullName??'');final contact=TextEditingController(text:existing?.contactNumber??'');final address=TextEditingController(text:existing?.businessAddress??'');var category=existing?.category??'';final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(existing==null?'Add Supplier':'Edit Supplier'),content:SizedBox(width:440,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Full Name',prefixIcon:Icon(Icons.person_outline))),const SizedBox(height:10),TextField(controller:contact,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Contact Number',prefixIcon:Icon(Icons.phone_outlined))),const SizedBox(height:10),TextField(controller:address,maxLines:2,decoration:const InputDecoration(labelText:'Business Address',prefixIcon:Icon(Icons.location_on_outlined))),const SizedBox(height:10),StatefulBuilder(builder:(ctx,setLocal)=>DropdownButtonFormField<String>(value:category.isEmpty?null:category,decoration:const InputDecoration(labelText:'Category (Optional)',prefixIcon:Icon(Icons.category_outlined)),items:[const DropdownMenuItem<String>(value:'',child:Text('No category')), ...ExpenseCategoryConfig.activeSubcategories.map((x)=>DropdownMenuItem(value:x,child:Text(x)))],onChanged:(v)=>setLocal(()=>category=v??'')))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(existing==null?'Add':'Save'))]));if(ok==true){try{final s=Supplier(id:existing?.id??'',fullName:name.text,businessAddress:address.text,contactNumber:contact.text,category:category);if(existing==null)await p.addSupplier(s);else await p.updateSupplier(s);if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(existing==null?'Supplier added.':'Supplier updated.'))); }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Unable to save supplier: $e')));}}name.dispose();contact.dispose();address.dispose();}
}
