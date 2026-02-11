Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "GUI Test"
$form.Size = New-Object System.Drawing.Size(400, 200)
$form.StartPosition = "CenterScreen"

$label = New-Object System.Windows.Forms.Label
$label.Text = "If you see this, WinForms works!"
$label.Location = New-Object System.Drawing.Point(20, 20)
$label.Size = New-Object System.Drawing.Size(350, 30)
$form.Controls.Add($label)

$btn = New-Object System.Windows.Forms.Button
$btn.Text = "Close"
$btn.Location = New-Object System.Drawing.Point(150, 80)
$btn.Add_Click({ $form.Close() })
$form.Controls.Add($btn)

$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
