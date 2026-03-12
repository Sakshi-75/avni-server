package org.avni.server.web.request;

import org.junit.Test;
import static org.junit.Assert.*;

public class AccountRequestTest {
    @Test
    public void testGettersAndSetters() {
        AccountRequest request = new AccountRequest();
        assertNull(request.getName());
        assertNull(request.getRegion());
        
        request.setName("TestAccount");
        request.setRegion("us-east-1");
        
        assertEquals("TestAccount", request.getName());
        assertEquals("us-east-1", request.getRegion());
    }
}
