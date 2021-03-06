﻿B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=4.19
@EndOfDesignText@
#IgnoreWarnings: 12
#Event: TextChanged(Text As String)
#DesignerProperty: Key: Editable, DisplayName: Editable, FieldType: Boolean, DefaultValue: True, Description: Whether the text of the CodeView is Editable
'Class module
Private Sub Class_Globals

	Private mCallBack As Object
    Private mEventName As String
	Private mForm As Form 'ignore
	Private mBase As Pane
	Private DesignerCVCalled As Boolean
	Private Initialized As Boolean 'ignore
	Private CustomViewName As String = "RichTextArea" 'Set this to the name of your custom view to provide meaningfull error logging
	Private fx As JFX
	
	'Custom View Specific Vars
	Private JO As JavaObject				'To hold the wrapped CoreArea object
	Private CustomViewNode As Node			'So that we can call B4x exposed methods on the object and don't have to use Javaobject's RunMethod for everything
	Private mBaseJO As JavaObject			'So that we can call Methods not exposed to B4x on the base pane.
	'For string matching
	Private BRACKET_PATTERN  As String
	Private SPACE_PATTERN As String
	Private offset As Int=2
	Public Font As Font
	Public Tag As Object
End Sub

'Initializes the object.
'For a custom view these should not be changed, if you need more parameters for a Custom view added by code, you can add them to the
'setup sub, or an additional Custom view control method
'Required for both designer and code setup. 
Public Sub Initialize (vCallBack As Object, vEventName As String)
	'CallBack Module and eventname are provided by the designer, and need to be provided if setting up in code
	'These allow callbacks to the defining module using CallSub(mCallBack,mEventname), or CallSub2 or CallSub3 to pass parameters, or CallSubDelayed....
	mCallBack = vCallBack
	mEventName = vEventName
	Font=fx.DefaultFont(15)
End Sub

Public Sub DesignerCreateView(Base As Pane, Lbl As Label, Props As Map)
	'Check this is not called from setup
	If Not(Props.GetDefault("CVfromsetup",False)) Then DesignerCVCalled = True
	
	'Assign vars to globals
	mBase = Base
	mBase.Tag=Me
	CSSUtils.SetBorder(mBase,0.5,fx.Colors.DarkGray,3)
	
	'So that we can Call Runmethod on the Base Panel to run non exposed methods
	mBaseJO = Base

	'This is passed from either the designer or setup
	mForm = Props.get("Form")

	'Initialize our wrapper object
	JO.InitializeNewInstance("org.fxmisc.richtext.CodeArea",Null)
	
	'Cast the wrapped view to a node so we can use B4x Node methods on it.
	CustomViewNode = GetObject
	
	'Add the stylesheet to colour matching words to the code area node
	'JO.RunMethodJO("getStylesheets",Null).RunMethod("add",Array(File.GetUri(File.DirAssets,"richtext.css")))
	
	
	'TextProperty Listener
	'Add an eventlistener to the ObservableValue "textProperty" so that we can get changes to the text
	Dim Event As Object = JO.CreateEvent("javafx.beans.value.ChangeListener","TextChanged","")
	JO.RunMethodJO("textProperty",Null).RunMethod("addListener",Array(Event))
	
	Dim Event As Object = JO.CreateEvent("javafx.beans.value.ChangeListener","SelectedTextChanged","")
	JO.RunMethodJO("selectedTextProperty",Null).RunMethod("addListener",Array(Event))
	
	Dim Event As Object = JO.CreateEvent("javafx.beans.value.ChangeListener","FocusChanged","")
	JO.RunMethodJO("focusedProperty",Null).RunMethod("addListener",Array(Event))
	
	'BaseChanged Listener
	'Add an eventlistener to the ReadOnlyObjectProperty "layoutBoundsProperty" on the Base Pane so that we can change the internal layout to fit
	Dim Event As Object = JO.CreateEvent("javafx.beans.value.ChangeListener","BaseResized","")
	mBaseJO.RunMethodJO("layoutBoundsProperty",Null).RunMethod("addListener",Array(Event))
	
	Dim O As Object = JO.CreateEventFromUI("javafx.event.EventHandler","KeyPressed",Null)
	JO.RunMethod("setOnKeyPressed",Array(O))
	JO.RunMethod("setFocusTraversable",Array(True))

	
	'Deal with properties we have been passed
	setEditable(Props.Get("Editable"))
	
	
	'Create your CustomView layout in sub CreateLayout
	CreateLayout
	
	'Other Custom Initializations
	InitializePatterns
	
	'Finally
	Initialized = True
End Sub

'Manual Setup of Custom View Pass Null to Pnl if adding to Form
Sub Setup(Form As Form,Pnl As Pane,Left As Int,Top As Int,Width As Int,Height As Int)
	'Check if DesignerCreateView has been called
	If DesignerCVCalled Then
		Log(CustomViewName & ": You should not call setup if you have defined this view in the designer")
		ExitApplication
	End If
	
	mForm = Form
	
	'Create our own base panel
	Dim Base As Pane
	Base.Initialize("")
	
	'If Null was passed, a Panel wii be created by casting, but it won't be initialized
	If Pnl.IsInitialized Then
		Pnl.AddNode(Base,Left,Top,Width,Height)
	Else
		Form.RootPane.AddNode(Base,Left,Top,Width,Height)
	End If
		
	'Set up variables to pass to DesignerCreateView so we don't have to maintain two identical subs to create the custom view
	Dim M As Map
	M.Initialize
	M.Put("Form",Form)
	M.Put("Editable",True)
	'As we are passing a map, we can use it to pass an additional flag for our own use 
	'with an ID unlikely To be used by B4a In the future
	M.Put("CVfromsetup",True)
	
	'We need a label to pass to DesignerCreateView
	Dim L As Label
	L.Initialize("")
	'Default text alignment
	CSSUtils.SetStyleProperty(L,"-fx-text-alignment","center")
	'Default size for Custom View text in designer is 15
	L.Font = fx.DefaultFont(15)
	
	'Call designer create view
	DesignerCreateView(Base,L,M)
	
End Sub


'Set the initial layout for the custom view
Private Sub CreateLayout
	
	'Add the wrapper object to customview mBase
    mBase.AddNode(CustomViewNode,offset,offset,mBase.Width-2*offset,mBase.Height-2*offset)
	
	'Add any other Nodes to the CustomView
	
End Sub

'Called by a BaseChanged Listener when mBase size changes
Private Sub BaseResized_Event(MethodName As String,Args() As Object) As Object			'ignore
	
	'Make our node added to the Base Pane the same size as the Base Pane
    CustomViewNode.PrefWidth = mBase.Width-2*offset
    CustomViewNode.PrefHeight = mBase.Height-2*offset
	
	'Make any changes needed to other integral nodes
	UpdateLayout
End Sub

'Update the layout as needed when the Base Pane has changed size.
Private Sub UpdateLayout
	
End Sub

Public Sub setLeft(left As Int)
	mBase.Left=left
End Sub

Sub setEnabled(enabled As Boolean)
	mBase.Enabled=enabled
	If enabled=False Then
		CustomViewNode.Alpha=0.5
		'CSSUtils.SetBackgroundColor(CustomViewNode,fx.Colors.DarkGray)
	Else
		CustomViewNode.Alpha=1.0
	End If
End Sub

Sub getBasePane As Pane
	Return mBase
End Sub

Sub getHeight As Double
	Return mBase.Height
End Sub

Sub setHeight(height As Double)
	mBase.PrefHeight=height
End Sub

Sub getWidth As Double
	Return mBase.width
End Sub

Sub setWidth(width As Double)
	mBase.PrefWidth=width
End Sub

Sub getParent As Node
	Return mBase.Parent
End Sub

Sub getSelectionStart As Double
	Return getSelection(0)
End Sub

Sub getSelectionEnd As Double
	Return getSelection(1)
End Sub

Sub setSelection(startIndex As Int,endIndex As Int)
	JO.RunMethod("selectRange",Array(startIndex,endIndex))
End Sub

Sub RequestFocus
	JO.RunMethod("requestFocus",Null)
End Sub

Sub setWrapText(wrap As Boolean)
	JO.RunMethod("setWrapText",Array(wrap))
End Sub

Sub FocusChanged_Event (MethodName As String,Args() As Object) As Object							'ignore
	Log("focus")
	Log(Args(2))
	If SubExists(mCallBack,mEventName & "_FocusChanged") Then
		CallSubDelayed2(mCallBack,mEventName & "_FocusChanged",Args(2))
	End If
End Sub

Sub KeyPressed_Event (MethodName As String, Args() As Object) As Object 'ignore
	Dim KEvt As JavaObject = Args(0)
	Dim result As String
	result=KEvt.RunMethod("getCode",Null)
	If SubExists(mCallBack,mEventName & "_KeyPressed") Then
		CallSubDelayed2(mCallBack,mEventName & "_KeyPressed",result)
	End If
End Sub

Sub getSelection As Int()
	Dim indexRange As String=JO.RunMethodJO("getSelection",Null).RunMethod("toString",Null)
	Dim selectionStart,selectionEnd As Int
	selectionStart=Regex.Split(",",indexRange)(0)
	selectionEnd=Regex.Split(",",indexRange)(1)
	Return Array As Int(selectionStart,selectionEnd)
End Sub

'Convenient method to assign a single style class.
Public Sub SetStyleClass(SetFrom As Int, SetTo As Int, Class As String)
	JO.RunMethod("setStyleClass",Array As Object(SetFrom, SetTo, Class))
End Sub

'Gets the value of the property length.
Public Sub Length As Int
	Return JO.RunMethod("getLength",Null)
End Sub

Public Sub getText As String
	Return JO.RunMethod("getText",Null)
End Sub

Public Sub setText(str As String)
	JO.RunMethod("replaceText",Array As Object(0, Length, str))
End Sub

'Replaces a range of characters with the given text.
Public Sub ReplaceText(Start As Int, ThisEnd As Int, str As String)
	JO.RunMethod("replaceText",Array As Object(Start, ThisEnd, str))
End Sub

'Get/Set the CodeArea Editable
Public Sub setEditable(Editable As Boolean)
	JO.RunMethod("setEditable",Array(Editable))
End Sub

Public Sub getEditable As Boolean
	Return JO.RunMethod("isEditable",Null)
End Sub

'Get the unwrapped object
Public Sub GetObject As Object
	Return JO
End Sub

'Get the unwrapped object As a JavaObject
Public Sub GetObjectJO As JavaObject
	Return JO
End Sub
'Comment if not needed

'Set the underlying Object, must be of correct type
Public Sub SetObject(Obj As Object)
	JO = Obj
End Sub

Public Sub LineHeight As Double
	Return Utils.MeasureMultilineTextHeight(Font,mBase.Width-2*offset,"a")
End Sub

Public Sub totalHeightEstimate As Double
	Dim height As Double=Max(50,Utils.MeasureMultilineTextHeight(Font,mBase.Width-2*offset,getText))
	Return height
End Sub

Sub AdjustHeight
	mBase.SetSize(mBase.Width,totalHeightEstimate)
End Sub

Sub setFontFamily(name As String)
	CSSUtils.SetStyleProperty(JO,"-fx-font-family",name)
	Font=fx.CreateFont(name,Font.Size,False,False)
End Sub

Sub setFontSzie(pixel As Int)
	CSSUtils.SetStyleProperty(JO,"-fx-font-size",pixel&"px")
	Font=fx.CreateFont(Font.FamilyName,pixel,False,False)
End Sub

'Callback from TextProperty Listener when the codearea text changes
Sub TextChanged_Event(MethodName As String,Args() As Object) As Object							'ignore
	JO.RunMethod("setStyleSpans",Array(0,ComputeHighlightingB4x(getText)))
	If SubExists(mCallBack,mEventName & "_TextChanged") Then
		CallSubDelayed3(mCallBack,mEventName & "_TextChanged",Args(1),Args(2))
	End If
End Sub

Sub SelectedTextChanged_Event(MethodName As String,Args() As Object) As Object							'ignore
	If SubExists(mCallBack,mEventName & "_SelectedTextChanged") Then
		CallSubDelayed3(mCallBack,mEventName & "_SelectedTextChanged",Args(1),Args(2))
	End If
End Sub

'Setup for pattern matching
Sub InitializePatterns
    BRACKET_PATTERN="<.*?>"
    SPACE_PATTERN = " *"
End Sub

'Create the style types for matching words
Sub ComputeHighlightingB4x(str As String) As JavaObject

	'Dim PMatcher As PatternMatcher = Pattern1.Matcher(Text)
    Dim Matcher As Matcher = Regex.Matcher($"(?<BRACKET>${BRACKET_PATTERN})|(?<SPACE>${SPACE_PATTERN})"$,str)
	Dim MJO As JavaObject = Matcher
	
	Dim SpansBuilder As JavaObject
	SpansBuilder.InitializeNewInstance("org.fxmisc.richtext.model.StyleSpansBuilder",Null)
	
	Dim Collections As JavaObject
	Collections.InitializeStatic("java.util.Collections")
	
	Dim LastKwEnd As Int = 0
	Dim StyleClass As String
	Dim Index As Int
	Do While Matcher.Find
		StyleClass = ""
		If Matcher.Group(2) <> Null Then
			Index = 2
			StyleClass = "space"
		Else
			If Matcher.Group(1) <> Null Then 
				Index = 1
				StyleClass = "bracket"
			End If
		End If
		Dim StrLength As Int = Matcher.GetStart(Index) - LastKwEnd
		SpansBuilder.RunMethod("add",Array(Collections.RunMethod("emptyList",Null),StrLength))
		StrLength = MJO.RunMethod("end",Null) - Matcher.GetStart(Index)
		SpansBuilder.RunMethod("add",Array(Collections.RunMethod("singleton",Array(StyleClass)),StrLength))
		LastKwEnd = Matcher.GetEnd(Index)
	Loop
	SpansBuilder.RunMethod("add",Array(Collections.RunMethod("emptyList",Null),str.Length - LastKwEnd))
	Return SpansBuilder.RunMethod("create",Null)		
End Sub
