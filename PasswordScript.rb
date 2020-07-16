rawData = ""
userArr = []
rawData.each_line{|l| line = l.split(","); userArr.push(line)}
userArr.each{|x|x.each{|y|y.strip!}}
userArr.each{|x| User.create(firstname:x[0],lastname1:x[1],lastname2:x[2],mail:x[3],mobile_phone:x[4],other_phone:x[5],password:x[6],password_confirmation:x[7])}

"Roberto,Valladares,Piedras,roberto@primeraraiz.com,5544545312,,Kurosaurio52+,Kurosaurio52+
Pablo,García,Santillán,pablogarciass@hotmail.com,5544545313,,Kurosaurio53+,Kurosaurio53+"