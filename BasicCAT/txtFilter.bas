﻿B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=StaticCode
Version=6.51
@EndOfDesignText@
'Static code module
Sub Process_Globals
	Private fx As JFX
End Sub

Sub createWorkFile(filename As String,path As String,sourceLang As String,sentenceLevel As Boolean) As ResumableSub
	Dim textContent As String
	Dim encoding As String
	encoding=icu4j.getEncoding(File.Combine(path,"source"),filename)
	Dim textReader As TextReader
	textReader.Initialize2(File.OpenInput(File.Combine(path,"source"),filename),encoding)
	textContent=textReader.ReadAll
	textReader.Close
	Dim workfile As Map
	workfile.Initialize
	workfile.Put("filename",filename)
	Dim innerFilename As String
	innerFilename=filename
	Dim sourceFiles As List
	sourceFiles.Initialize
	Dim sourceFileMap As Map
	sourceFileMap.Initialize
	Dim segmentsList As List
	segmentsList.Initialize
	Dim inbetweenContent As String
	wait for (segmentation.segmentedTxt(textContent,sentenceLevel,sourceLang,path)) Complete (segmentedText As List)
	For Each source As String In segmentedText
		Dim bitext As List
		bitext.Initialize
		If source.Trim="" Then 'newline or empty space
			inbetweenContent=inbetweenContent&source
			Continue
		Else if source.Trim<>"" Then
			bitext.add(source.Trim)
			bitext.Add("")
			bitext.Add(inbetweenContent&source) 'inbetweenContent contains crlf and spaces between sentences
			bitext.Add(innerFilename)
			Dim extra As Map
			extra.Initialize
			bitext.Add(extra)
			inbetweenContent=""
		End If
		segmentsList.Add(bitext)
	Next
	sourceFileMap.Put(innerFilename,segmentsList)
	sourceFiles.Add(sourceFileMap)
	workfile.Put("files",sourceFiles)
	
	Dim json As JSONGenerator
	json.Initialize(workfile)

	File.WriteString(File.Combine(path,"work"),filename&".json",json.ToPrettyString(4))
	Return True
End Sub

Sub generateFile(filename As String,path As String,projectFile As Map)
	Dim innerfilename As String=filename
	Dim result As StringBuilder
	result.Initialize
	Dim workfile As Map
	Dim json As JSONParser
	json.Initialize(File.ReadString(File.Combine(path,"work"),filename&".json"))
	workfile=json.NextObject
	Dim sourceFiles As List
	sourceFiles=workfile.Get("files")
	For Each sourceFileMap As Map In sourceFiles
		Dim segments As List
		segments=sourceFileMap.Get(innerfilename)
		Dim index As Int=-1
		For Each bitext As List In segments
			index=index+1
			Dim source,target,fullsource,translation As String
			source=bitext.Get(0)
			target=bitext.Get(1)
			fullsource=bitext.Get(2)
			Dim extra As Map
			extra=bitext.Get(4)
			If extra.ContainsKey("neglected") Then
				If extra.get("neglected")="yes" Then
					Continue
				End If
			End If
			'Log(source)
			'Log(target)
			'Log(fullsource)
			If target="" Or target=source Then
				translation=fullsource
			Else
				If shouldAddSpace(projectFile.Get("source"), _ 
				                  projectFile.Get("target"), _ 
				                  index,segments) Then
					target=target&" "
				End If
				
				If Utils.LanguageHasSpace(Main.currentProject.projectFile.Get("target"))=False Then
					source=segmentation.removeSpacesAtBothSides(Main.currentProject.path,Main.currentProject.projectFile.Get("source"),source,Utils.previousText(segments,index,"source"),Utils.getMap("settings",Main.currentProject.projectFile).GetDefault("remove_space",False))
					fullsource=segmentation.removeSpacesAtBothSides(Main.currentProject.path,Main.currentProject.projectFile.Get("source"),fullsource,Utils.previousText(segments,index,"fullsource"),Utils.getMap("settings",Main.currentProject.projectFile).GetDefault("remove_space",False))
				End If
				
				translation=fullsource.Replace(source,target)
			End If

			'result=result&translation
			result.Append(translation)
		Next
	Next
	
	File.WriteString(File.Combine(path,"target"),filename,result.ToString)
	Main.updateOperation(filename&" generated!")
End Sub


Sub shouldAddSpace(sourceLang As String,targetLang As String,index As Int,segmentsList As List) As Boolean
	Dim bitext As List=segmentsList.Get(index)
	Dim fullsource As String=bitext.Get(2)
	If Utils.LanguageHasSpace(sourceLang)=False And Utils.LanguageHasSpace(targetLang)=True Then
		If index+1<=segmentsList.Size-1 Then
			Dim nextBitext As List
			nextBitext=segmentsList.Get(index+1)
			Dim nextfullsource As String=nextBitext.Get(2)
			If fullsource.EndsWith(CRLF)=False And nextfullsource.StartsWith(CRLF)=False Then
				Try
					If Regex.IsMatch("\s",nextfullsource.CharAt(0))=False And Regex.IsMatch("\s",fullsource.CharAt(fullsource.Length-1))=False Then
						Return True
					End If
				Catch
					Log(LastException)
				End Try
			End If
		End If
	End If
	Return False
End Sub

Sub mergeSegment(sourceTextArea As RichTextArea)
	Dim index As Int
	index=Main.editorLV.Items.IndexOf(sourceTextArea.Parent)
	If index+1>Main.currentProject.segments.Size-1 Then
		Return
	End If
	Dim bitext,nextBiText As List
	bitext=Main.currentProject.segments.Get(index)
	nextBiText=Main.currentProject.segments.Get(index+1)
	Dim source As String
	source=bitext.Get(0)
		
	If bitext.Get(3)<>nextBiText.Get(3) Then
		fx.Msgbox(Main.MainForm,"Cannot merge segments as these two belong to different files.","")
		Return
	End If
		
	Dim pane,nextPane As Pane

	pane=Main.editorLV.Items.Get(index)
	nextPane=Main.editorLV.Items.Get(index+1)
	Dim targetTa,nextSourceTa,nextTargetTa As RichTextArea
	nextSourceTa=nextPane.GetNode(0).Tag
	nextTargetTa=nextPane.GetNode(1).tag
	Dim fullsource,nextFullSource As String
	fullsource=bitext.Get(2)
	nextFullSource=nextBiText.Get(2)
		
	Dim sourceWhitespace,targetWhitespace,fullsourceWhitespace As String
	sourceWhitespace=""
	targetWhitespace=""
	fullsourceWhitespace=""
	
	Dim sourceLang,targetLang As String
	sourceLang=Main.currentProject.projectFile.Get("source")
	targetLang=Main.currentProject.projectFile.Get("target")
	If Utils.LanguageHasSpace(sourceLang)=True Then
		Try
			If Regex.IsMatch("\s",fullsource.CharAt(fullsource.Length-1)) Or Regex.IsMatch("\s",nextFullSource.CharAt(0)) Then
				sourceWhitespace=" "
			End If
		Catch
			Log(LastException)
		End Try

	End If
	If Utils.LanguageHasSpace(targetLang)=True Then
		targetWhitespace=" "
	End If
	
	If Utils.LanguageHasSpace(sourceLang)=True Then
		Try
			If Regex.IsMatch("\s",fullsource.CharAt(fullsource.Length-1)) Or Regex.IsMatch("\s",nextFullSource.CharAt(0)) Then
				fullsourceWhitespace=" "
			End If
		Catch
			Log(LastException)
		End Try
	End If
		
	sourceTextArea.Text=source.Trim&sourceWhitespace&nextSourceTa.Text.Trim
	sourceTextArea.Tag=sourceTextArea.Text
		
	targetTa=pane.GetNode(1).Tag
	targetTa.Text=targetTa.Text&targetWhitespace&nextTargetTa.Text


	bitext.Set(0,sourceTextArea.Text)
	bitext.Set(1,targetTa.Text)



	bitext.Set(2,Utils.rightTrim(fullsource)&fullsourceWhitespace&Utils.leftTrim(nextFullSource))

		
	Main.currentProject.segments.RemoveAt(index+1)
	Main.editorLV.Items.RemoveAt(Main.editorLV.Items.IndexOf(sourceTextArea.Parent)+1)
End Sub

Sub splitSegment(sourceTextArea As RichTextArea)
    filterGenericUtils.splitInternalSegment(sourceTextArea,False,Main,Main.editorLV,Main.currentProject.segments)
End Sub

Sub previewText As String
	Dim text As StringBuilder
	text.Initialize
	If Main.editorLV.Items.Size<>Main.currentProject.segments.Size Then
		Return ""
	End If
	Dim segments As List=Main.currentProject.segments
	For i=Max(0,Main.currentProject.lastEntry-3) To Min(Main.currentProject.lastEntry+7,Main.currentProject.segments.Size-1)

        Try
			Dim p As Pane
			p=Main.editorLV.Items.Get(i)
		Catch
			Log(LastException)
			Continue
		End Try


		Dim sourceTextArea As RichTextArea
		Dim targetTextArea As RichTextArea
		sourceTextArea=p.GetNode(0).Tag
		targetTextArea=p.GetNode(1).Tag
		Dim bitext As List
		bitext=segments.Get(i)
		Dim source,target,fullsource,translation As String
		source=sourceTextArea.Text
		target=targetTextArea.Text
		fullsource=bitext.Get(2)
		If target="" Then
			translation=fullsource
		Else
			If shouldAddSpace(Main.currentProject.projectFile.Get("source"),Main.currentProject.projectFile.Get("target"),i,Main.currentProject.segments) Then
				target=target&" "
			End If
			If Utils.LanguageHasSpace(Main.currentProject.projectFile.Get("target"))=False Then
				source=segmentation.removeSpacesAtBothSides(Main.currentProject.path,Main.currentProject.projectFile.Get("source"),source,Utils.previousText(segments,i,"source"),Utils.getMap("settings",Main.currentProject.projectFile).GetDefault("remove_space",False))
				fullsource=segmentation.removeSpacesAtBothSides(Main.currentProject.path,Main.currentProject.projectFile.Get("source"),fullsource,Utils.previousText(segments,i,"fullsource"),Utils.getMap("settings",Main.currentProject.projectFile).GetDefault("remove_space",False))
			End If
			translation=fullsource.Replace(source,target)
		End If

		If i=Main.currentProject.lastEntry Then
			translation=$"<span id="current" name="current" >${translation}</span>"$
		End If
		'text=text&translation
		text.Append(translation)
	Next
	Return text.ToString
End Sub