package org.avni.server.service;

import org.avni.server.dao.application.FormElementRepository;
import org.joda.time.DateTime;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class FormElementServiceTest {
    @Mock private FormElementRepository formElementRepository;
    private FormElementService service;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        service = new FormElementService(formElementRepository);
    }
    
    @Test
    public void testIsNonScopeEntityChanged() {
        DateTime dateTime = DateTime.now();
        when(formElementRepository.existsByLastModifiedDateTimeGreaterThan(dateTime)).thenReturn(true);
        
        boolean result = service.isNonScopeEntityChanged(dateTime);
        
        assertTrue(result);
        verify(formElementRepository).existsByLastModifiedDateTimeGreaterThan(dateTime);
    }
}
