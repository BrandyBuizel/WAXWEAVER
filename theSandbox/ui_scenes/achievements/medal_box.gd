extends NinePatchRect

func setData(tex:Texture2D,nameText:String,description:String):
	if tex != null:
		$Icon.texture = tex
	$Icon/NameText.text = nameText
	$Icon/DescText.text = description
