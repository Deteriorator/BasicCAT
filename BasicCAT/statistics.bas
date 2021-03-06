﻿B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=6.51
@EndOfDesignText@
Sub Class_Globals
	Private fx As JFX
	Private frm As Form
	Private WebView1 As WebView
	Private totalSourceWords,totalTargetWords,totalSourceSentences,totalTargetSentences As Int
End Sub

'Initializes the object. You can add parameters to this method if needed.
Public Sub Initialize
	frm.Initialize("frm",600,200)
	frm.RootPane.LoadLayout("statistics")
End Sub

Public Sub Show
	frm.Show
	buildTable
End Sub

Sub fillData(filename As String) As String
	Dim sourceWords,targetWords,sourceSentences,targetSentences As Int=0
	Dim segments As List
	segments=Main.currentProject.getAllSegments(filename)
	For Each bitext As List In segments
		Dim extra As Map
		extra=bitext.Get(4)
		Dim source,target As String
		source=bitext.Get(0)
		target=bitext.Get(1)
		If extra.GetDefault("neglected","no") = "yes" Then
			Continue
		End If
		If source<>"" Then
			sourceWords=sourceWords+calculateWords(source,Main.currentProject.projectFile.Get("source"))
		End If
		
		sourceSentences=sourceSentences+1
		
		If target<>"" Then
			targetSentences=targetSentences+1
			targetWords=targetWords+calculateWords(target,Main.currentProject.projectFile.Get("target"))
		End If
	Next
	
	totalSourceWords=totalSourceWords+sourceWords
	totalTargetWords=totalTargetWords+targetWords
	totalSourceSentences=totalSourceSentences+sourceSentences
	totalTargetSentences=totalTargetSentences+targetSentences
	
	Dim percent As String
	percent=targetSentences/sourceSentences*100
	percent=percent.SubString2(0,Min(4,percent.Length))&"%"
	
	Dim one As String
	one=$"<tr>
	<td>${filename}</td>
	<td>${sourceWords}</td>
	<td>${targetWords}</td>
	<td>${sourceSentences}</td>
	<td>${targetSentences}</td>
	<td>${percent}</td>
	</tr>"$
	
	Return one
End Sub

Sub fillTotalData() As String
	Dim percent As String
	percent=totalTargetSentences/totalSourceSentences*100
	percent=percent.SubString2(0,Min(4,percent.Length))&"%"
	
	Dim one As String
	one=$"<tr>
	<td>Total</td>
	<td>${totalSourceWords}</td>
	<td>${totalTargetWords}</td>
	<td>${totalSourceSentences}</td>
	<td>${totalTargetSentences}</td>
	<td>${percent}</td>
	</tr>"$
	
	Return one
End Sub

Sub buildTable
	Dim result As StringBuilder
	result.Initialize
	Dim htmlhead As String
	htmlhead=$"<!DOCTYPE HTML>
	<html>
	<head>
	<meta charset="utf-8"/>
	<style type="text/css">
	p {font-size: 18px}
	table {width: 100%}
	</style>
	</head><body>
	<table border="1" cellpadding="0" cellspacing="1">
	<tr>
	<th rowspan="2">Filename</th>
	<th colspan="2">Words</th>
	<th colspan="2">Sentences</th>
	<th rowspan="2">Progress</th>

	</tr>
	<tr>
	<th>Source</th><th>Target</th>
	<th>Source</th><th>Target</th>

	</tr>"$
	result.Append(htmlhead)
	Dim htmlend As String
	htmlend="</table></body></html>"

	For Each filename As String In Main.currentProject.files
		result.Append(fillData(filename))
	Next
	result.Append(fillTotalData)
	result.Append(htmlend)
	WebView1.LoadHtml(result.ToString)
End Sub

Sub calculateWords(text As String,lang As String) As Int
	If Utils.LanguageHasSpace(lang) Then
		If lang.StartsWith("ko") Then
			Return calculateHanzi(text)
		End If
		Return calculateWordsForLanguageWithSpace(text)
	Else
		Return calculateHanzi(text)
	End If
End Sub

Sub calculateWordsForLanguageWithSpace(text As String) As Int
	text=TagRemoved(text)
	text=Regex.Replace(" +",text," ")
	Return Regex.Split(" ",text).Length
End Sub

Sub calculateHanzi(text As String) As Int
	text=TagRemoved(text)
	text=Regex.Replace("[\x00-\x19\x21-\xff]+",text,"字") 'Replace English words to Hanzi
	text=text.Replace(" ","")
	Return text.Length
End Sub

Sub TagRemoved(text As String) As String
	text=Regex.Replace2("<.*?>",32,text,"")
	Return text
End Sub

Sub Button1_MouseClicked (EventData As MouseEvent)
	Dim sb As StringBuilder
	sb.Initialize
	For Each filename As String In Main.currentProject.files
		Dim wordCount As Int
		Dim set As B4XSet
		set.Initialize
		For Each segment As List In Main.currentProject.getAllSegments(filename)
			Dim source As String=segment.Get(0)
			If set.Contains(source)=False Then
				set.Add(source)
				wordCount=wordCount+calculateWords(source,Main.currentProject.projectFile.Get("source"))
			End If
		Next
        sb.Append(filename).Append(": ").Append(set.Size).Append(" segments ").Append(wordCount).Append(" words").Append(CRLF)
	Next
	fx.Msgbox(frm,sb.ToString,"Result")
End Sub
