codeunit 50002 Tests
{
    Subtype = Test;

    [Test]
    procedure PassingTest()
    var
        item: Record Item;
    begin
        item.FindFirst();
    end;

    [Test]
    procedure PassingTestPageTest()
    var
        itemCard: TestPage "Item Card";
    begin
        itemCard.OpenEdit();
        itemCard.Description.SetValue('New Description');
        itemCard.Close();        
    end;

    [Test]
    procedure FailingTest()
    var
        item: Record Item;
        itemNo: Code[20];
    begin
        item.FindFirst();
        itemNo := item."No.";

        item.Init();
        item."No." := itemNo;
        item.Insert();
    end;

    [Test]
    procedure FailingTestPageTest()
    var
        itemCard: TestPage "Item Card";
    begin
        itemCard.OpenEdit();
        itemCard."Base Unit of Measure".SetValue('DUMMYVALUE');
        itemCard.Close();        
    end;
}