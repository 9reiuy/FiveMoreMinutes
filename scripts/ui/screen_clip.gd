extends Control

## 手机屏幕裁剪容器：严格对应 Phone.png 的屏幕可显示区（clip_contents）。
## 顶栏/图标/锁屏/设置等自绘内容全部委托 bedroom_phone._draw_screen
## 绘制到本画布上，从而被严格裁剪在屏幕内；消息列表/速联列表等子控件
## 也随本容器自动裁剪，任何内容都不会画到手机框外。


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	# 手机内容随状态/时间高频重绘，这里每帧同步重绘保证裁剪内容一致。
	queue_redraw()


func _draw() -> void:
	var phone := get_parent()
	if phone == null or not phone.has_method("_draw_screen"):
		return
	# 把绘制原点平移回手机局部坐标系，手机的绘制代码可继续使用原坐标。
	draw_set_transform(-position)
	phone._draw_screen(self)
