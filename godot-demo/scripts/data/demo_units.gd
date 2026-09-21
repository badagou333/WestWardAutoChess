extends RefCounted

# Single-encounter test values, not first-chapter balance or full skill definitions.
const ALIASES := {"rabbit":"wild_hunter","deer":"wild_hunter","ox":"guard_monk","crane":"sparrow_spirit","fox":"foxfire_imp"}
const HEROES := {
	"guard_monk": {"name":"护寺棍僧","quality":"white","hp":310.0,"damage":14.0,"interval":1.15,"move":0.50,"range":1,"skill1":"前排普攻","skill2":"护盾待实现","skill3":"升星暂增属性"},
	"wild_hunter": {"name":"山野猎户","quality":"white","hp":145.0,"damage":22.0,"interval":0.85,"move":0.42,"range":1,"skill1":"近战普攻","skill2":"猎犬待实现","skill3":"升星暂增属性"},
	"sparrow_spirit": {"name":"山雀精","quality":"white","hp":90.0,"damage":17.0,"interval":0.92,"move":0.46,"range":3,"skill1":"远程投射","skill2":"射程增益待实现","skill3":"升星暂增属性"},
	"herbal_spirit_child": {"name":"药灵童子","quality":"white","hp":100.0,"damage":24.0,"interval":1.20,"move":0.58,"range":3,"skill1":"治疗最低血比","skill2":"毒草散待实现","skill3":"升星暂增属性"},
	"foxfire_imp": {"name":"狐火小妖","quality":"white","hp":96.0,"damage":20.0,"interval":1.25,"move":0.42,"range":3,"skill1":"小范围狐火","skill2":"灼烧待实现","skill3":"升星暂增属性"}
}
const SHOP := ["guard_monk","wild_hunter","sparrow_spirit","herbal_spirit_child","foxfire_imp"]
